//
//  AnnotationDocument.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import MediaKit
import FinderItem
import NativeImage
import Essentials
import Observation


extension UTType {
    static var annotationProject: UTType {
        UTType(importedAs: "com.Vaida.annotation-project")
    }
}


@Observable
final class AnnotationDocument: ReferenceFileDocument {
    
    struct Snapshot {
        let annotations: [Annotation]
        let labels: [LabelSnapshot]
    }

    struct LabelSnapshot: Codable {
        let title: String
        let color: Color

        init(_ label: Label) {
            self.title = label.title
            self.color = label.color
        }

        var label: Label { Label(title: title, color: color) }
    }

    enum DocumentError: LocalizedError {
        case missingComponent(String)
        case invalidManifestPath(String)
        case duplicateImageID(UUID)
        case missingMedia(String)
        case unreadableMedia(String)
        case invalidCoordinate(image: String)
        case duplicateLabel(String)

        var errorDescription: String? {
            switch self {
            case .missingComponent(let name): "The project is missing \(name)."
            case .invalidManifestPath(let path): "The project contains an invalid media path: \(path)."
            case .duplicateImageID(let id): "The project contains the image ID \(id) more than once."
            case .missingMedia(let path): "The project is missing the media file \(path)."
            case .unreadableMedia(let path): "The media file \(path) is not a readable image."
            case .invalidCoordinate(let image): "The project contains an invalid annotation rectangle for \(image)."
            case .duplicateLabel(let title): "The project contains more than one label named “\(title)”."
            }
        }
    }
    
    // core
    /// The images, with real annotations hidden inside.
    var annotations: [Annotation]
    
    var labels: [String: Label]
    
    // layout
    var isExporting = false
    var exportingProgress = Progress()
    
    var isImporting = false
    var importingProgress = Progress()
    
    var selectedItems: Set<Annotation.ID> = []
    var previousSelectedItems: Set<Annotation.ID> = []
    
    var selectedLabel: Label = Label(title: "New Label", color: .green)
    
    var scrollProxy: ScrollViewProxy? = nil
    
    
    var isShowingExportDialog = false
    var isShowingImportDialog = false
    
    var isShowingAutoAnnotate = false
    var isShowingAutoDetect = false

    /// Non-fatal issues found while recovering a project package.
    var loadWarnings: [String] = []
    

    init(annotations: [Annotation] = [], labels: Array<Label> = []) {
        self.annotations = annotations
        self.labels = .init(uniqueKeysWithValues: labels.map { ($0.title, $0) })
        reconcileState()
    }

    static nonisolated var readableContentTypes: [UTType] { [.annotationProject] }
    static nonisolated var writableContentTypes: [UTType] { [.annotationProject, .folder] }
    
    init(from wrapper: FileWrapper) throws {
        guard let mainWrapper = wrapper.fileWrappers?["annotations.json"],
              let data = mainWrapper.regularFileContents else { throw DocumentError.missingComponent("annotations.json") }
        guard let mediaFileWrapper = wrapper.fileWrappers?["Media"],
              let container = mediaFileWrapper.fileWrappers else { throw DocumentError.missingComponent("Media") }
        
        let document = try [_AnnotationImport](data: data, format: .json)
        
        // create Annotation
        var seenIDs: Set<UUID> = []
        var recoveredAnnotations: [Annotation] = []
        var warnings: [String] = []
        recoveredAnnotations.reserveCapacity(document.count)
        for documentItem in document {
            do {
                guard seenIDs.insert(documentItem.id).inserted else { throw DocumentError.duplicateImageID(documentItem.id) }
                guard documentItem.image.hasPrefix("Media/"),
                      !documentItem.image.contains(".."),
                      !documentItem.image.dropFirst("Media/".count).contains("/") else {
                    throw DocumentError.invalidManifestPath(documentItem.image)
                }
                let filename = String(documentItem.image.dropFirst("Media/".count))
                guard let mediaItem = container[filename], let mediaData = mediaItem.regularFileContents else {
                    throw DocumentError.missingMedia(documentItem.image)
                }
                guard let image = NSImage(data: mediaData), image.cgImage != nil else {
                    throw DocumentError.unreadableMedia(documentItem.image)
                }
                guard documentItem.annotations.allSatisfy({ $0.coordinates.isValid }) else {
                    throw DocumentError.invalidCoordinate(image: documentItem.image)
                }
                recoveredAnnotations.append(Annotation(id: documentItem.id, image: image, annotations: documentItem.annotations.map(\.annotations)))
            } catch {
                warnings.append(error.localizedDescription)
            }
        }
        self.annotations = recoveredAnnotations
        self.loadWarnings = warnings
        
        if let labelsWrapper = wrapper.fileWrappers?["labels.plist"],
           let data = labelsWrapper.regularFileContents {
            let set = try [Label](data: data, format: .plist)
            let normalized = try Self.validatedLabels(set)
            self.labels = .init(uniqueKeysWithValues: normalized.map { ($0.title, $0) })
        } else {
            let set = Set(Set(recoveredAnnotations.__labels.map({ Label(title: $0, color: .green) })))
            self.labels = .init(uniqueKeysWithValues: set.map { ($0.title, $0) })
        }
        reconcileState()
    }

    convenience init(configuration: ReadConfiguration) throws {
        let wrapper = configuration.file
        try self.init(from: wrapper)
    }
    
    func snapshot(contentType: UTType) throws -> Snapshot {
        reconcileState()
        return Snapshot(annotations: annotations, labels: labels.values.map(LabelSnapshot.init))
    }
    
    
    func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        
        Task { @MainActor in
            self.isExporting = true
        }
        defer {
            Task { @MainActor in self.isExporting = false }
        }
        
        let reporter = self.exportingProgress
        let data: Data
        
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        
        if configuration.contentType == .annotationProject {
            let annotationsImport: [_AnnotationImport] = snapshot.annotations.map {
                _AnnotationImport(id: $0.id, image: "Media/\($0.id).heic", annotations: $0.annotations.map(\.export))
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            data = try encoder.encode(annotationsImport)
            
            let labelsWrapper = try FileWrapper(regularFileWithContents: snapshot.labels.map(\.label).data(using: .plist))
            labelsWrapper.preferredFilename = "labels.plist"
            wrapper.addFileWrapper(labelsWrapper)
        } else {
            // create AnnotationDocument.AnnotationExport
            let annotationsExport: [_AnnotationExportFolder] = snapshot.annotations.compactMap {
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
            
            let oldItems = Array(container.keys)
            let newItems = snapshot.annotations.map{ $0.id.description + ".heic" }
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
                    let _newItems = snapshot.annotations.filter({ addedItems.contains($0.id.description + ".heic" )})
                    let _newWrappers = try _newItems.map { item in
                        let image = try item.image.data(format: .heic)
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
                Task { @MainActor in
                    reporter.totalUnitCount = Int64(snapshot.annotations.count)
                    reporter.completedUnitCount = 0
                }
                
                let _newWrappers = try snapshot.annotations.map { item in
                    let image = try item.image.data(format: .heic)
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
            
            if configuration.contentType == .annotationProject {
                Task { @MainActor in
                    reporter.totalUnitCount = Int64(snapshot.annotations.count)
                    reporter.completedUnitCount = 0
                }
                let _newWrappers = try snapshot.annotations.map { item in
                    let image = try item.image.data(format: .heic)
                    let imageWrapper = FileWrapper(regularFileWithContents: image)
                    imageWrapper.preferredFilename = "\(item.id).heic"
                    
                    Task { @MainActor in reporter.completedUnitCount += 1 }
                    
                    return imageWrapper
                }
                
                for wrapper in _newWrappers {
                    mediaWrapper.addFileWrapper(wrapper)
                }
            } else {
                let source = snapshot.annotations.filter { !$0.annotations.isEmpty }
                Task { @MainActor in 
                    reporter.totalUnitCount = Int64(source.count)
                    reporter.completedUnitCount = 0
                }
                
                let _newWrappers = try source.map { item in
                    let image = try item.image.data(format: .heic)
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

        var id: String { title }
        
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
            case title, color
        }

        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            color = try container.decode(Color.self, forKey: .color)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try container.encode(color, forKey: .color)
        }
    }
}


extension AnnotationDocument {

    func replaceState(annotations newAnnotations: [Annotation], labels newLabels: [Label], selection: Set<Annotation.ID>, undoManager: UndoManager?) {
        let oldAnnotations = annotations
        let oldLabels = labels.values.map { Label(title: $0.title, color: $0.color) }
        let oldSelection = selectedItems
        annotations = newAnnotations
        labels = Dictionary(uniqueKeysWithValues: newLabels.map { ($0.title, $0) })
        selectedItems = selection
        reconcileState()
        undoManager?.registerUndo(withTarget: self) { document in
            document.replaceState(annotations: oldAnnotations, labels: oldLabels, selection: oldSelection, undoManager: undoManager)
        }
    }

    private static func validatedLabels(_ labels: [Label]) throws -> [Label] {
        var titles: Set<String> = []
        return try labels.map { label in
            let title = label.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw DocumentError.duplicateLabel(label.title) }
            guard titles.insert(title).inserted else { throw DocumentError.duplicateLabel(title) }
            return Label(title: title, color: label.color)
        }
    }

    /// Restores relationships that can become stale after loading or a bulk edit.
    func reconcileState() {
        selectedItems.formIntersection(annotations.lazy.map(\.id))

        for title in annotations.__labels where labels[title] == nil {
            labels[title] = Label(title: title, color: .green)
        }

        if let selected = labels[selectedLabel.title] {
            selectedLabel = selected
        } else if let first = labels.values.sorted().first {
            selectedLabel = first
        }
    }

    enum LabelMutationError: LocalizedError {
        case emptyName
        case duplicateName(String)

        var errorDescription: String? {
            switch self {
            case .emptyName: "A label name cannot be empty."
            case .duplicateName(let name): "A label named “\(name)” already exists."
            }
        }
    }

    @discardableResult
    func addLabel(title rawTitle: String, color: Color, undoManager: UndoManager?) throws -> Label {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw LabelMutationError.emptyName }
        guard labels[title] == nil else { throw LabelMutationError.duplicateName(title) }
        let label = Label(title: title, color: color)
        labels[title] = label
        undoManager?.registerUndo(withTarget: self) { document in
            document.labels[title] = nil
            undoManager?.registerUndo(withTarget: document) { document in
                _ = try? document.addLabel(title: title, color: color, undoManager: undoManager)
            }
        }
        return label
    }
    
    /// Replaces the existing items with a new set of items.
    func replaceItems(with newItems: [Annotation], undoManager: UndoManager?, animation: Animation? = .default) {
        let oldItems = annotations
        
        self.annotations = newItems
        reconcileState()
        
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
            document.insertAnnotation(undoManager: undoManager, annotationID: annotationID, item: deletedItem, at: deletedItemIndex)
        }
    }

    private func insertAnnotation(undoManager: UndoManager?, annotationID: Annotation.ID, item: Annotation.Annotations, at index: Int) {
        guard let annotationIndex = annotations.firstIndex(where: { $0.id == annotationID }) else { return }
        annotations[annotationIndex].annotations.insert(item, at: min(index, annotations[annotationIndex].annotations.endIndex))
        undoManager?.registerUndo(withTarget: self) { document in
            document.removeAnnotations(undoManager: undoManager, annotationID: annotationID, annotationsID: item.id)
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
        selectedItems.remove(annotationID)
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.annotations.insert(removedElement, at: min(index, document.annotations.endIndex))
            
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
            document.replaceColor(label: label, with: oldColor, undoManager: undoManager)
        }
    }
    
    func rename(label oldName: String, with newName: String, undoManager: UndoManager?) {
        let normalizedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }
        guard oldName == normalizedName || self.labels[normalizedName] == nil else { return }
        undoManager?.setActionName("Rename \"\(oldName)\" with \"\(newName)\"")
        var indexes: [Int: RangeSet<Int>] = [:] // [Annotation.Index: [Annotation.Annotations.Index]]
        indexes.reserveCapacity(annotations.count)
        
        for annotation in self.annotations.enumerated() {
            let list = annotation.element.annotations.indices { $0.label == oldName }
            indexes[annotation.offset] = list
        }
        
        for (key, value) in indexes {
            for _value in value.ranges.flatten() {
                self.annotations[key].annotations[_value].label = normalizedName
            }
        }
        
        guard let removed = self.labels[oldName] else { return }
        self.labels[oldName] = nil
        self.labels[normalizedName] = Label(title: normalizedName, color: removed.color)
        if selectedLabel.title == oldName { selectedLabel = self.labels[normalizedName]! }
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.rename(label: normalizedName, with: oldName, undoManager: undoManager)
        }
    }
    
    static let preview = AnnotationDocument(annotations: [
        Annotation(image: NativeImage(named: "image")!, annotations: [
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
        try Task.checkCancellation()
        let contentType = try source.contentType
        
        switch contentType {
        case .annotationProject:
            let file = try AnnotationDocument(from: FileWrapper(url: source.url, options: []))
            newItems.append(contentsOf: file.annotations)
            await MainActor.run { reporter.completedUnitCount += 1 }
            
        case .folder:
            let wrapper = try FileWrapper(url: source.url, options: [])
            if let mainWrapper = wrapper.fileWrappers?["annotations.json"], let value = mainWrapper.regularFileContents {
                let annotationImport = try JSONDecoder().decode([AnnotationExport].self, from: value)
                let childReporter = Progress(totalUnitCount: Int64(annotationImport.count), parent: reporter, pendingUnitCount: 1)
                for item in annotationImport {
                    try Task.checkCancellation()
                    guard item.image.hasPrefix("Media/"), !item.image.contains("..") else {
                        throw AnnotationDocument.DocumentError.invalidManifestPath(item.image)
                    }
                    let image = try source.appending(path: item.image).load(.image)
                    guard item.annotations.allSatisfy({ $0.coordinates.isValid }) else {
                        throw AnnotationDocument.DocumentError.invalidCoordinate(image: item.image)
                    }
                    newItems.append(Annotation(image: image, annotations: item.annotations.map(\.annotations)))
                    await MainActor.run { childReporter.completedUnitCount += 1 }
                }
            } else {
                let children = try Array(source.children(range: .enumeration))
                let childReporter = Progress(totalUnitCount: Int64(children.count), parent: reporter, pendingUnitCount: 1)
                for child in children {
                    try Task.checkCancellation()
                    if let image = try? child.load(.image) { newItems.append(Annotation(image: image)) }
                    await MainActor.run { childReporter.completedUnitCount += 1 }
                }
            }
            
        case .quickTimeMovie, .movie, .video, UTType("com.apple.m4v-video"):
            let asset = try await source.load(.avAsset)
            let frames = try await asset.generateFramesStream(maximumFrameCount: 300)
            let childReporter = Progress(totalUnitCount: 300, parent: reporter, pendingUnitCount: 1)
            for try await frame in frames {
                try Task.checkCancellation()
                newItems.append(Annotation(image: NativeImage(cgImage: frame.image)))
                await MainActor.run { childReporter.completedUnitCount += 1 }
            }
            await MainActor.run { childReporter.totalUnitCount = childReporter.completedUnitCount }
            
        default:
            let image = try source.load(.image)
            newItems.append(Annotation(image: image))
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

extension AVAsset {
    
    /// Returns the iterator of all the frames of the video.
    func generateFramesStream(maximumFrameCount: Int = 300) async throws -> AsyncThrowingStream<(image: CGImage, actualTime: CMTime), Error> {
        let vidLength: CMTime = try await self.load(.duration)
        
        guard let video = try await self.loadTracks(withMediaType: .video).first else { throw AlertManager("Failed to load video", message: "No video found.") }
        
        let seconds = vidLength.seconds
        let frameRate = try await video.load(.nominalFrameRate)
        
        let sourceFrameCount = max(Int(seconds * Double(frameRate)), 1)
        let requiredFramesCount = min(sourceFrameCount, max(maximumFrameCount, 1))
        
        let step = max(Int(vidLength.value / Int64(requiredFramesCount)), 1)
        
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.requestedTimeToleranceAfter = CMTime(value: CMTimeValue(step / 2), timescale: vidLength.timescale)
        imageGenerator.requestedTimeToleranceBefore = CMTime(value: CMTimeValue(step / 2), timescale: vidLength.timescale)
        
        let requestedTimes = (0..<requiredFramesCount).map { CMTime(value: Int64(step * $0), timescale: vidLength.timescale) }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for time in requestedTimes {
                        try Task.checkCancellation()
                        continuation.yield(try await imageGenerator.image(at: time))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
}
