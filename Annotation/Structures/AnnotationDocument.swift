//
//  AnnotationDocument.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import UniformTypeIdentifiers
import NativeImage
import AVFoundation
import MediaKit
import FinderItem


extension UTType {
    static var annotationProject: UTType {
        UTType(importedAs: "com.Vaida.annotation-project")
    }
}


final class AnnotationDocument: ReferenceFileDocument {
    
    typealias Snapshot = Array<Annotation>
    
    // core
    /// The images, with real annotations hidden inside.
    @Published var annotations: [Annotation]
    
    @Published var labels: [String: Label]
    
    // layout
    @Published var isExporting = false
    @Published var exportingProgress = Progress()
    
    @Published var isImporting = false
    @Published var importingProgress = Progress()
    
    @Published var selectedItems: Set<Annotation.ID> = []
    var previousSelectedItems: Set<Annotation.ID> = []
    
    @Published var selectedLabel: Label = Label(title: "New Label", color: .green)
    
    @Published var scrollProxy: ScrollViewProxy? = nil
    
    
    @Published var isShowingExportDialog = false
    @Published var isShowingImportDialog = false
    
    @Published var isShowingAutoAnnotate = false
    @Published var isShowingAutoDetect = false
    

    init(annotations: [Annotation] = [], labels: Array<Label> = []) {
        self.annotations = annotations
        self.labels = .init(uniqueKeysWithValues: labels.map { ($0.title, $0) })
    }

    static nonisolated var readableContentTypes: [UTType] { [.annotationProject] }
    static nonisolated var writableContentTypes: [UTType] { [.annotationProject, .folder] }
    
    init(from wrapper: FileWrapper) throws {
        guard let mainWrapper = wrapper.fileWrappers?["annotations.json"],
              let mediaFileWrapper = wrapper.fileWrappers?["Media"],
              let data = mainWrapper.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        
        let document = try [_AnnotationImport](data: data, format: .json)
        
        // create Annotation
        guard let _container = mediaFileWrapper.fileWrappers else { throw CocoaError(.fileReadCorruptFile) }
        nonisolated(unsafe) let container = consume _container
        
        let annotations: [Annotation] = document.compactMap { documentItem in
            guard let mediaItem = container[String(documentItem.image.dropFirst("Media/".count))] else { return nil }
            return Annotation(id: documentItem.id, representation: .fileWrapper(mediaItem), annotations: documentItem.annotations.map(\.annotations))
        }
        self.annotations = annotations
        
        if let labelsWrapper = wrapper.fileWrappers?["labels.plist"],
           let data = labelsWrapper.regularFileContents {
            let set = try [Label](data: data, format: .plist)
            self.labels = .init(uniqueKeysWithValues: set.map { ($0.title, $0) })
        } else {
            let set = Set(Set(annotations.__labels.map({ Label(title: $0, color: .green) })))
            self.labels = .init(uniqueKeysWithValues: set.map { ($0.title, $0) })
        }
    }

    convenience init(configuration: ReadConfiguration) throws {
        let wrapper = configuration.file
        try self.init(from: wrapper)
    }
    
    func snapshot(contentType: UTType) throws -> [Annotation] {
        annotations
    }
    
    
    func fileWrapper(snapshot: [Annotation], configuration: WriteConfiguration) throws -> FileWrapper {
        
        Task { @MainActor in
            self.isExporting = true
        }
        
        let reporter = self.exportingProgress
        let data: Data
        
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        
        if configuration.contentType == .annotationProject {
            let annotationsImport: [_AnnotationImport] = snapshot.map {
                _AnnotationImport(id: $0.id, image: "Media/\($0.id).heic", annotations: $0.annotations.map(\.export))
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            data = try encoder.encode(annotationsImport)
            
            let labelsWrapper = try FileWrapper(regularFileWithContents: Array(labels.values).data(using: .plist))
            labelsWrapper.preferredFilename = "labels.plist"
            wrapper.addFileWrapper(labelsWrapper)
        } else {
            // create AnnotationDocument.AnnotationExport
            let annotationsExport: [_AnnotationExportFolder] = snapshot.compactMap {
                guard !$0.annotations.isEmpty else { return nil }
                return _AnnotationExportFolder(image: "Media/\($0.id).heic", annotations: $0.annotations.map(\.export))
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            data = try encoder.encode(annotationsExport)
        }
        
        let mainWrapper = FileWrapper(regularFileWithContents: data)
        mainWrapper.preferredFilename = "annotations.json"
        wrapper.addFileWrapper(mainWrapper)
        
        var mediaWrapper = FileWrapper(directoryWithFileWrappers: [:])
        
        func wrappers(for snapshot: [Annotation]) -> [FileWrapper] {
            snapshot.map { item in
                Task { @MainActor in reporter.completedUnitCount += 1 }
                
                switch item.representation.rep {
                case let .image(image):
                    let image = try! image.data(format: .heic)
                    let imageWrapper = FileWrapper(regularFileWithContents: image)
                    imageWrapper.preferredFilename = "\(item.id).heic"
                    
                    return imageWrapper
                    
                case let .fileWrapper(fileWrapper):
                    return fileWrapper
                }
            }
        }
        
        if let existingFile = configuration.existingFile, let container = existingFile.fileWrappers?["Media"]?.fileWrappers, configuration.contentType == .annotationProject {
            
            let oldItems = Array(container.keys)
            let newItems = snapshot.map{ $0.id.description + ".heic" }
            let commonItems = Set(oldItems).intersection(newItems)
            
            var addedItems = newItems
            addedItems.removeAll(where: { commonItems.contains($0) })
            var removedItems = oldItems
            removedItems.removeAll(where: { commonItems.contains($0) })
            
            if removedItems.count <= addedItems.count || removedItems.count < commonItems.count {
                mediaWrapper = FileWrapper(directoryWithFileWrappers: container)
                
                let totalCount = Int64(removedItems.count + addedItems.count)
                Task { @MainActor in
                    reporter.totalUnitCount = totalCount
                    reporter.completedUnitCount = 0
                }
                
                if !removedItems.isEmpty {
                    var index = 0
                    while index < removedItems.count {
                        guard let item = container.first(where: { $0.key == removedItems[index] }) else { index += 1; continue }
                        
                        mediaWrapper.removeFileWrapper(item.value)
                        Task { @MainActor in reporter.completedUnitCount += 1 }
                        
                        index += 1
                    }
                }
                
                if !addedItems.isEmpty {
                    let _newItems = snapshot.filter({ addedItems.contains($0.id.description + ".heic" )})
                    let _newWrappers = wrappers(for: _newItems)
                    
                    for wrapper in _newWrappers {
                        mediaWrapper.addFileWrapper(wrapper)
                    }
                }
            } else {
                Task { @MainActor in
                    reporter.totalUnitCount = Int64(snapshot.count)
                    reporter.completedUnitCount = 0
                }
                
                let _newWrappers = wrappers(for: snapshot)
                
                for wrapper in _newWrappers {
                    mediaWrapper.addFileWrapper(wrapper)
                }
            }
        } else {
            
            if configuration.contentType == .annotationProject {
                Task { @MainActor in
                    reporter.totalUnitCount = Int64(snapshot.count)
                    reporter.completedUnitCount = 0
                }
                let _newWrappers = wrappers(for: snapshot)
                
                for wrapper in _newWrappers {
                    mediaWrapper.addFileWrapper(wrapper)
                }
            } else {
                let source = snapshot.filter { !$0.annotations.isEmpty }
                Task { @MainActor in 
                    reporter.totalUnitCount = Int64(source.count)
                    reporter.completedUnitCount = 0
                }
                
                let _newWrappers = wrappers(for: source)
                
                for wrapper in _newWrappers {
                    mediaWrapper.addFileWrapper(wrapper)
                }
            }
        }
        
        mediaWrapper.preferredFilename = "Media"
        wrapper.addFileWrapper(mediaWrapper)
        Task { @MainActor in
            self.isExporting = false
        }
        
        return wrapper
        
    }
    
    fileprivate struct _AnnotationImport: Codable {
        
        var id: UUID
        var image: String
        var annotations: [AnnotationExport.Annotations]
        
    }
    
    fileprivate struct _AnnotationExportFolder: Codable {
        
        var image: String
        var annotations: [AnnotationExport.Annotations]
        
    }
    
    @Observable
    final class Label: Identifiable, Hashable, Comparable, Codable {
        
        var title: String
        
        var color: Color
        
        
        init(title: String, color: Color) {
            self.title = title
            self.color = color
        }
        
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(self.title)
        }
        
        static func < (lhs: AnnotationDocument.Label, rhs: AnnotationDocument.Label) -> Bool {
            lhs.title < rhs.title
        }
        
        static func == (_ lhs: AnnotationDocument.Label, _ rhs: AnnotationDocument.Label) -> Bool {
            lhs.title == rhs.title && lhs.color == rhs.color
        }
        
        enum CodingKeys: String, CodingKey {
            case _title = "title"
            case _color = "color"
        }
    }
}


extension AnnotationDocument {
    
    /// Replaces the existing items with a new set of items.
    func replaceItems(with newItems: [Annotation], undoManager: UndoManager?, animation: Animation? = .default) {
        let oldItems = annotations
        
        self.objectWillChange.send()
        self.annotations = newItems
        
        undoManager?.registerUndo(withTarget: self) { document in
            // Because you recurse here, redo support is automatic.
            document.replaceItems(with: oldItems, undoManager: undoManager, animation: animation)
        }
    }
    
    /// Relocates the specified items, and registers an undo action.
    func moveItemsAt(offsets: IndexSet, toOffset: Int, undoManager: UndoManager?) {
        undoManager?.setActionName("Move items")
        annotations.move(fromOffsets: offsets, toOffset: toOffset)
        
        undoManager?.registerUndo(withTarget: self) { document in
            guard var newToOffset = offsets.first else { return }
            
            let _offset = {
                toOffset > newToOffset ? -1 * offsets.count : 0
            }()
            if toOffset < newToOffset {
                newToOffset += offsets.count
            }
            
            let newFromOffset = IndexSet((toOffset + _offset)..<((toOffset + _offset) + offsets.count))
            
            document.moveItemsAt(offsets: newFromOffset, toOffset: newToOffset, undoManager: undoManager)
        }
        
    }
    
    /// Deletes the items at a specified set of offsets, and registers an undo action.
    func delete(offsets: IndexSet, undoManager: UndoManager?) {
        undoManager?.setActionName("Delete items")
        var elements: [Annotation] = []
        elements.reserveCapacity(offsets.count)
        
        for offset in offsets {
            elements.append(self.annotations[offset])
        }
        
        self.annotations.remove(atOffsets: offsets)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.insert(at: offsets, elements, undoManager: undoManager)
        }
    }
    
    func insert(at indexes: IndexSet, _ item: [Annotation], undoManager: UndoManager?) {
        undoManager?.setActionName("insert items")
        guard let first = indexes.first else { return }
        guard indexes.count == item.count else { return }
        
        self.annotations.insert(contentsOf: item, at: first)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.delete(offsets: indexes, undoManager: undoManager)
        }
    }
    
    func apply(undoManager: UndoManager?, action: (()->Void)) {
        let oldItems = annotations
        self.objectWillChange.send()
        action()
        
        undoManager?.registerUndo(withTarget: self) { document in
            // Use the replaceItems symmetric undoable-redoable function.
            document.replaceItems(with: oldItems, undoManager: undoManager)
        }
    }
    
    /// Remove the item given the indexes. Return on not found.
    func removeAnnotations(undoManager: UndoManager?, annotationID: Annotation.ID, annotationsID: Annotation.Annotations.ID) {
        guard let annotationIndex = self.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
        guard let deletedItemIndex = self.annotations[annotationIndex].annotations.firstIndex(where: { $0.id == annotationsID }) else { return }
        
        let deletedItem = self.annotations[annotationIndex].annotations[deletedItemIndex]
        
        self.annotations[annotationIndex].annotations.remove(at: deletedItemIndex)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.appendAnnotations(undoManager: undoManager, annotationID: annotationID, item: deletedItem)
        }
    }
    
    func appendAnnotations(undoManager: UndoManager?, annotationID: Annotation.ID, item: Annotation.Annotations) {
        guard let annotationIndex = self.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
        
        self.annotations[annotationIndex].annotations.append(item)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.removeAnnotations(undoManager: undoManager, annotationID: annotationID, annotationsID: item.id)
        }
    }
    
    func removeAnnotation(undoManager: UndoManager?, annotationID: Annotation.ID) {
        undoManager?.setActionName("Remove an image")
        guard let index = self.annotations.firstIndex(where : { $0.id == annotationID }) else { return }
        let removedElement = self.annotations.remove(at: index)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.annotations.insert(removedElement, at: index)
            
            undoManager?.registerUndo(withTarget: self) { document in
                document.removeAnnotation(undoManager: undoManager, annotationID: annotationID)
            }
        }
    }
    
    func remove(undoManager: UndoManager?, label: Label) {
        undoManager?.setActionName("Remove \"\(label.title)\"")
        var indexes: [Int: RangeSet<Int>] = [:] // [Annotation.Index: [Annotation.Annotations.Index]]
        indexes.reserveCapacity(annotations.count)
        
        for annotation in self.annotations.enumerated() {
            let list = annotation.element.annotations.indices { $0.label == label.title }
            indexes[annotation.offset] = list
        }
        
        var values: [Int: [Annotation.Annotations]] = [:]
        for (key, value) in indexes {
            var list: [Annotation.Annotations] = []
            
            for _value in value.ranges.flatten().reversed() {
                list.append(self.annotations[key].annotations[_value])
                self.annotations[key].annotations.remove(at: _value)
            }
            
            values[key] = list
        }
        
        withAnimation {
            self.labels[label.title] = nil
        }
        
        undoManager?.registerUndo(withTarget: self) { document in
            withAnimation {
                for (key, value) in values {
                    document.annotations[key].annotations.append(contentsOf: value)
                }
                document.labels[label.title] = label
            }
            
            undoManager?.registerUndo(withTarget: self) { document in
                document.remove(undoManager: undoManager, label: label)
            }
        }
    }
    
    func replaceColor(label: String, with color: Color, undoManager: UndoManager?) {
        guard let oldColor = self.labels[label]?.color else { return }
        
        undoManager?.setActionName("Set color for \(label)")
        
        self.labels[label]?.color = color
        
        undoManager?.registerUndo(withTarget: self) { document in
            self.replaceColor(label: label, with: oldColor, undoManager: undoManager)
        }
    }
    
    func rename(label oldName: String, with newName: String, undoManager: UndoManager?) {
        undoManager?.setActionName("Rename \"\(oldName)\" with \"\(newName)\"")
        var indexes: [Int: RangeSet<Int>] = [:] // [Annotation.Index: [Annotation.Annotations.Index]]
        indexes.reserveCapacity(annotations.count)
        
        for annotation in self.annotations.enumerated() {
            let list = annotation.element.annotations.indices { $0.label == oldName }
            indexes[annotation.offset] = list
        }
        
        for (key, value) in indexes {
            for _value in value.ranges.flatten() {
                self.annotations[key].annotations[_value].label = newName
            }
        }
        
        guard let removed = self.labels[oldName] else { return }
        self.labels[oldName] = nil
        self.labels[newName] = Label(title: newName, color: removed.color)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.rename(label: newName, with: oldName, undoManager: undoManager)
        }
    }
    
    static let preview = AnnotationDocument(annotations: [
        Annotation(representation: .image(NativeImage(named: "image")!), annotations: [
            Annotation.Annotations(label: "label 1", coordinates: .center(x: 432, y: 749, width: 204, height: 520)),
            Annotation.Annotations(label: "label 2", coordinates: .center(x: 818, y: 863, width: 139, height: 349)),
            Annotation.Annotations(label: "label 3", coordinates: .center(x: 185, y: 277, width:  88, height: 109))
        ])
    ], labels: [
        Label(title: "label 1", color: .red),
        Label(title: "label 2", color: .green),
        Label(title: "label 3", color: .blue),
    ])
    
}


func loadItems(from sources: [FinderItem], reporter: Progress) async throws -> [Annotation] {
    
    var newItems: [Annotation] = []
    await MainActor.run {
        reporter.totalUnitCount = Int64(sources.count)
        reporter.completedUnitCount = 0
    }
    
    for source in sources {
        let contentType = try source.contentType
        
        switch contentType {
        case .annotationProject, .folder:
            guard let file = try? AnnotationDocument(from: FileWrapper(url: source.url, options: [])) else { fallthrough }
            newItems.append(contentsOf: file.annotations)
            await MainActor.run { reporter.completedUnitCount += 1 }
            
        case .folder:
            do {
                let wrapper = try FileWrapper(url: source.url, options: [])
                guard let mainWrapper = wrapper.fileWrappers?["annotations.json"] else { fallthrough }
                guard let value = mainWrapper.regularFileContents else { fallthrough }
                let annotationImport = try JSONDecoder().decode([AnnotationExport].self, from: value)
                
                let childReporter = Progress(totalUnitCount: Int64(annotationImport.count), parent: reporter, pendingUnitCount: 1)
                
                for item in annotationImport {
                    await MainActor.run { childReporter.completedUnitCount += 1 }
                    let annotation = Annotation(representation: .fileWrapper(try FileWrapper(at: source.appending(path: item.image))), annotations: item.annotations.map(\.annotations))
                    newItems.append(annotation)
                }
            } catch {
                fallthrough
            }
            
        case .folder:
            let children = try Array(source.children(range: .enumeration))
            
            let childReporter = Progress(totalUnitCount: Int64(children.count), parent: reporter, pendingUnitCount: 1)
            
            for child in children {
                await MainActor.run { childReporter.completedUnitCount += 1 }
                guard child.isFile else { continue }
                let annotation = Annotation(representation: .fileWrapper(try FileWrapper(at: child)))
                newItems.append(annotation)
            }
            
        case .quickTimeMovie, .movie, .video, UTType("com.apple.m4v-video"):
            guard let asset = try? await source.load(.avAsset) else { fallthrough }
            let frameCount = try await asset.frameCount
            
            let childReporter = Progress(totalUnitCount: Int64(frameCount), parent: reporter, pendingUnitCount: 1)
            
            let frames = try await asset.generateFramesStream()
                .map {
                    let annotation = Annotation(id: UUID(), representation: .image(NativeImage(cgImage: $0.image)), annotations: [])
                    await MainActor.run { childReporter.completedUnitCount += 1 }
                    return annotation
                }
                .sequence
            
            newItems.append(contentsOf: frames)
            
        case .image:
            try newItems.append(Annotation(id: UUID(), representation: .fileWrapper(FileWrapper(at: source)), annotations: []))
            
        default:
            await MainActor.run { reporter.completedUnitCount += 1 }
        }
    }
    
    await MainActor.run { 
        reporter.completedUnitCount = reporter.totalUnitCount
    }
    return newItems
}


struct AnnotationExport: Codable {
    
    let image: String
    let annotations: [Annotations]
    
    struct Annotations: Equatable, Hashable, Encodable, Decodable {
        
        var label: String
        var coordinates: Annotation.Annotations.Coordinate
        
        var annotations: Annotation.Annotations {
            return Annotation.Annotations(label: label, coordinates: coordinates)
        }
    }
    
}
