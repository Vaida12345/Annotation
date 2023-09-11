//
//  AnnotationDocument.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import UniformTypeIdentifiers
import Support
import AVFoundation

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
    
    @Published var labels: Set<Label>
    
    // layout
    @Published var isExporting = false
    @Published var exportingProgress = Progress()
    
    @Published var isImporting = false
    @Published var importingProgress = Progress()
    
    @Published var selectedItems: Set<Annotation.ID> = []
    var previousSelectedItems: Set<Annotation.ID> = []
    
    @Published var scrollProxy: ScrollViewProxy? = nil

    init(annotations: [Annotation] = [], labels: Set<Label> = []) {
        self.annotations = annotations
        self.labels = labels
    }

    static nonisolated var readableContentTypes: [UTType] { [.annotationProject] }
    static nonisolated var writableContentTypes: [UTType] { [.annotationProject, .folder] }
    
    init(from wrapper: FileWrapper) throws {
        guard let mainWrapper = wrapper.fileWrappers?["annotations.json"],
              let mediaFileWrapper = wrapper.fileWrappers?["Media"],
              let data = mainWrapper.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        
        let document = try [_AnnotationImport](data: data, format: .json)
        
        // create Annotation
        guard let container = mediaFileWrapper.fileWrappers else { throw CocoaError(.fileReadCorruptFile) }
        
        let annotations: [Annotation] = document.concurrent.compactMap { documentItem in
            print(documentItem.image, container[documentItem.image])
            guard let mediaItem = container[String(documentItem.image.dropFirst("Media/".count))] else { return nil }
            guard let data = mediaItem.regularFileContents else { return nil }
            guard let image = NSImage(data: data) else { return nil }
            
            return Annotation(id: documentItem.id, image: image, annotations: documentItem.annotations.map(\.annotations))
        }
        self.annotations = annotations
        
        if let labelsWrapper = wrapper.fileWrappers?["labels.plist"],
           let data = labelsWrapper.regularFileContents
        {
            self.labels = try .init(data: data, format: .plist)
        } else {
            self.labels = Set(Set(annotations.__labels.map({ Label(title: $0, color: .green) })))
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
        
        print("saving file")
        Task { @MainActor in
            self.isExporting = true
        }
        
        let reporter = self.exportingProgress
        let data: Data
        
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        
        if configuration.contentType == .annotationProject {
            let annotationsImport: [_AnnotationImport] = snapshot.concurrent.map {
                _AnnotationImport(id: $0.id, image: "Media/\($0.id).heic", annotations: $0.annotations.map(\.export))
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            data = try encoder.encode(annotationsImport)
            
            let labelsWrapper = try FileWrapper(regularFileWithContents: labels.data(using: .plist))
            labelsWrapper.preferredFilename = "labels.plist"
            wrapper.addFileWrapper(labelsWrapper)
        } else {
            // create AnnotationDocument.AnnotationExport
            let annotationsExport: [_AnnotationExportFolder] = snapshot.concurrent.compactMap {
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
        
        if let existingFile = configuration.existingFile, let container = existingFile.fileWrappers?["Media"]?.fileWrappers, configuration.contentType == .annotationProject {
            print("performing save with old data")
            
            let oldItems = Array(container.keys)
            let newItems = snapshot.map{ $0.id.description + ".heic" }
            let commonItems = oldItems.intersection(newItems)
            
            var addedItems = newItems
            addedItems.removeAll(where: { commonItems.contains($0) })
            var removedItems = oldItems
            removedItems.removeAll(where: { commonItems.contains($0) })
            
            print("result", commonItems.count, addedItems.count, removedItems.count)
            
            if removedItems.count <= addedItems.count || removedItems.count < commonItems.count {
                mediaWrapper = FileWrapper(directoryWithFileWrappers: container)
                
                reporter.totalUnitCount = Int64(removedItems.count + addedItems.count)
                
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
                    let _newWrappers = _newItems.concurrent.map { item in
                        let image = item.image.data(using: .heic)!
                        let imageWrapper = FileWrapper(regularFileWithContents: image)
                        imageWrapper.preferredFilename = "\(item.id).heic"
                        
                        Task { @MainActor in reporter.completedUnitCount += 1 }
                        
                        return imageWrapper
                    }
                    
                    for wrapper in _newWrappers {
                        mediaWrapper.addFileWrapper(wrapper)
                    }
                }
                print("done")
            } else {
                reporter.totalUnitCount = Int64(snapshot.count)
                
                let _newWrappers = snapshot.concurrent.map { item in
                    let image = item.image.data(using: .heic)!
                    let imageWrapper = FileWrapper(regularFileWithContents: image)
                    imageWrapper.preferredFilename = "\(item.id).heic"
                    
                    Task { @MainActor in reporter.completedUnitCount += 1 }
                    
                    return imageWrapper
                }
                
                for wrapper in _newWrappers {
                    mediaWrapper.addFileWrapper(wrapper)
                }
            }
        } else {
            reporter.totalUnitCount = Int64(snapshot.count)
            print("performing save without old data")
            
            if configuration.contentType == .annotationProject {
                let _newWrappers = snapshot.concurrent.map { item in
                    let image = item.image.data(using: .heic)!
                    let imageWrapper = FileWrapper(regularFileWithContents: image)
                    imageWrapper.preferredFilename = "\(item.id).heic"
                    
                    Task { @MainActor in reporter.completedUnitCount += 1 }
                    
                    return imageWrapper
                }
                
                for wrapper in _newWrappers {
                    mediaWrapper.addFileWrapper(wrapper)
                }
            } else {
                let source = snapshot.filter { !$0.annotations.isEmpty }
                
                let _newWrappers = source.concurrent.map { item in
                    let image = item.image.data(using: .heic)!
                    let imageWrapper = FileWrapper(regularFileWithContents: image)
                    imageWrapper.preferredFilename = "\(item.id).heic"
                    
                    Task { @MainActor in reporter.completedUnitCount += 1 }
                    
                    return imageWrapper
                }
                
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
        print("file saved")
        
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
    
    struct Label: Codable, Identifiable, Hashable {
        
        var title: String
        
        var color: Color
        
        
        var id: String { title }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(self.title)
        }
        
    }
}


extension AnnotationDocument {
    
    /// Replaces the existing items with a new set of items.
    func replaceItems(with newItems: [Annotation], undoManager: UndoManager?, animation: Animation? = .default) {
        let oldItems = annotations
        
        withAnimation(animation) {
            annotations = newItems
        }
        
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
        withAnimation {
            action()
        }
        
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
        undoManager?.setActionName("Remove \"\(label)\"")
        var indexes: [Int: [Int]] = [:] // [Annotation.Index: [Annotation.Annotations.Index]]
        indexes.reserveCapacity(annotations.count)
        
        for annotation in self.annotations.enumerated() {
            let list = annotation.element.annotations.indexes { $0.label == label.title }
            indexes[annotation.offset] = list
        }
        
        var values: [Int: [Annotation.Annotations]] = [:]
        for (key, value) in indexes {
            var list: [Annotation.Annotations] = []
            list.reserveCapacity(value.count)
            
            for _value in value.reversed() {
                list.append(self.annotations[key].annotations[_value])
                self.annotations[key].annotations.remove(at: _value)
            }
            
            values[key] = list
        }
        
        self.labels.remove(label)
        
        undoManager?.registerUndo(withTarget: self) { document in
            for (key, value) in values {
                document.annotations[key].annotations.append(contentsOf: value)
            }
            self.labels.insert(label)
            
            undoManager?.registerUndo(withTarget: self) { document in
                document.remove(undoManager: undoManager, label: label)
            }
        }
    }
    
    func replaceColor(label: String, with color: Color, undoManager: UndoManager?) {
        guard let firstIndex = self.labels.firstIndex(where: { $0.title == label }) else { return }
        
        undoManager?.setActionName("Set color for \(label)")
        
        let removed = self.labels.remove(at: firstIndex)
        self.labels.insert(Label(title: label, color: color))
        
        undoManager?.registerUndo(withTarget: self) { document in
            self.replaceColor(label: label, with: removed.color, undoManager: undoManager)
        }
    }
    
    func rename(label oldName: String, with newName: String, undoManager: UndoManager?) {
        undoManager?.setActionName("Rename \"\(oldName)\" with \"\(newName)\"")
        var indexes: [Int: [Int]] = [:] // [Annotation.Index: [Annotation.Annotations.Index]]
        indexes.reserveCapacity(annotations.count)
        
        for annotation in self.annotations.enumerated() {
            let list = annotation.element.annotations.indexes { $0.label == oldName }
            indexes[annotation.offset] = list
        }
        
        for (key, value) in indexes {
            for _value in value {
                self.annotations[key].annotations[_value].label = newName
            }
        }
        
        guard let firstIndex = self.labels.firstIndex(where: { $0.title == oldName }) else { return }
        let removed = self.labels.remove(at: firstIndex)
        self.labels.insert(Label(title: newName, color: removed.color))
        
        
        undoManager?.registerUndo(withTarget: self) { document in
            for (key, value) in indexes {
                for _value in value {
                    document.annotations[key].annotations[_value].label = oldName
                }
            }
            
            self.labels.remove(Label(title: newName, color: removed.color))
            self.labels.insert(Label(title: oldName, color: removed.color))
            
            undoManager?.registerUndo(withTarget: self) { document in
                document.rename(label: oldName, with: newName, undoManager: undoManager)
            }
        }
    }
    
}


func loadItems(from sources: [FinderItem], reporter: Progress) async throws -> [Annotation] {
    
    var newItems: [Annotation] = []
    reporter.totalUnitCount = Int64(sources.count)
    
    for source in sources {
        guard let contentType = source.contentType else { continue }
        
        switch contentType {
        case .annotationProject, .folder:
            guard let file = try? AnnotationDocument(from: FileWrapper(url: source.url, options: [])) else { fallthrough }
            newItems.append(contentsOf: file.annotations)
            Task { @MainActor in reporter.completedUnitCount += 1 }
            
        case .folder:
            do {
                let wrapper = try FileWrapper(url: source.url, options: [])
                guard let mainWrapper = wrapper.fileWrappers?["annotations.json"] else { fallthrough }
                guard let value = mainWrapper.regularFileContents else { fallthrough }
                let annotationImport = try JSONDecoder().decode([AnnotationExport].self, from: value)
                
                let childReporter = Progress(totalUnitCount: Int64(annotationImport.count), parent: reporter, pendingUnitCount: 1)
                
                let _newItems = await withTaskGroup(of: Annotation?.self) { group in
                    for item in annotationImport {
                        group.addTask {
                            guard let image = NSImage(at: source.with(subPath: item.image)) else { return nil }
                            let annotation = Annotation(image: image, annotations: item.annotations.map(\.annotations))
                            
                            Task { @MainActor in childReporter.completedUnitCount += 1 }
                            
                            return annotation
                        }
                    }
                    
                    var iterator = group.makeAsyncIterator()
                    return await iterator.allObjects(reservingCapacity: annotationImport.count)
                }
                
                newItems.append(contentsOf: _newItems.compacted())
            } catch {
                print(error)
                fallthrough
            }
            
        case .folder:
            let children = try source.children(range: .enumeration)
            
            let childReporter = Progress(totalUnitCount: Int64(children.count), parent: reporter, pendingUnitCount: 1)
            
            let _newItems = await withTaskGroup(of: Annotation?.self) { group in
                for child in children {
                    group.addTask {
                        guard let image = child.image else { return nil }
                        let annotation = Annotation(image: image)
                        
                        Task { @MainActor in childReporter.completedUnitCount += 1 }
                        
                        return annotation
                    }
                }
                
                var iterator = group.makeAsyncIterator()
                return await iterator.allObjects(reservingCapacity: children.count)
            }
            
            newItems.append(contentsOf: _newItems.filter { $0 != nil }.map { $0! })
            
        case .quickTimeMovie, .movie, .video, UTType("com.apple.m4v-video"):
            guard let asset = AVAsset(at: source) else { fallthrough }
            guard let frameCount = asset.framesCount else { fallthrough }
            
            let childReporter = Progress(totalUnitCount: Int64(frameCount), parent: reporter, pendingUnitCount: 1)
            
            let frames = try await asset.generateFramesStream()
                .stream
                .map {
                    defer { Task { @MainActor in childReporter.completedUnitCount += 1 } }
                    return Annotation(id: UUID(), image: NativeImage(cgImage: $0.image), annotations: [])
                }
                .sequence
            
            newItems.append(contentsOf: frames)
            
        default:
            guard let image = source.image else { continue }
            newItems.append(Annotation(id: UUID(), image: image, annotations: []))
            Task { @MainActor in reporter.completedUnitCount += 1 }
        }
    }
    
    reporter.completedUnitCount = reporter.totalUnitCount
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
