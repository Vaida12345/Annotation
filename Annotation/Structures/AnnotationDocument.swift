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
    @Published var annotations: [Annotation]
    
    // layout
    @Published var isExporting = false
    @Published var exportingProgress = 0.0
    
    @Published var isImporting = false
    @Published var importingProgress = 0.0

    init(annotations: [Annotation] = []) {
        self.annotations = annotations
    }

    static nonisolated var readableContentTypes: [UTType] { [.annotationProject] }
    static nonisolated var writableContentTypes: [UTType] { [.annotationProject, .folder] }
    
    init(from wrapper: FileWrapper) throws {
        let mainWrapper = wrapper.fileWrappers!["annotations.json"]
        guard let mediaFileWrapper = wrapper.fileWrappers!["Media"] else { throw CocoaError(.fileReadCorruptFile) }
        guard let data = mainWrapper?.regularFileContents,
              let document = try? JSONDecoder().decode([AnnotationExport].self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // create Annotation
        let container = mediaFileWrapper.fileWrappers!
        
        self.annotations = document.concurrent.compactMap { documentItem in
            guard let mediaItem = container["\(documentItem.id.description).png"] else { return nil }
            let image = NSImage(data: mediaItem.regularFileContents!)!
            
            return Annotation(id: documentItem.id, image: image, annotations: documentItem.annotations.map(\.annotations))
        }
        print("import: finished")
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
        
        let reporter = ProgressReporter(totalUnitCount: 1) { progress in
            Task { @MainActor in
                self.exportingProgress = progress
            }
        }
        
        let data: Data
        
        if configuration.contentType == .annotationProject {
            let annotationsExport: [AnnotationExport] = snapshot.concurrent.map {
                AnnotationExport(id: $0.id, image: "Media/\($0.id).png", annotations: $0.annotations.map(\.export))
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            data = try encoder.encode(annotationsExport)
        } else {
            // create AnnotationDocument.AnnotationExport
            let annotationsExport: [AnnotationExportFolder] = snapshot.concurrent.compactMap {
                guard !$0.annotations.isEmpty else { return nil }
                return AnnotationExportFolder(image: "Media/\($0.id).png", annotations: $0.annotations.map(\.export))
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            data = try encoder.encode(annotationsExport)
        }
        
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        let mainWrapper = FileWrapper(regularFileWithContents: data)
        mainWrapper.preferredFilename = "annotations.json"
        wrapper.addFileWrapper(mainWrapper)
        
        var mediaWrapper = FileWrapper(directoryWithFileWrappers: [:])
        
        if let existingFile = configuration.existingFile, let container = existingFile.fileWrappers!["Media"]?.fileWrappers, configuration.contentType == .annotationProject {
            print("performing save with old data")
            
            let oldItems = Array(container.keys)
            let newItems = snapshot.map{ $0.id.description + ".png" }
            let commonItems = oldItems.intersection(newItems)
            
            var addedItems = newItems
            addedItems.removeAll(where: { commonItems.contains($0) })
            var removedItems = oldItems
            removedItems.removeAll(where: { commonItems.contains($0) })
            
            print("result", commonItems.count, addedItems.count, removedItems.count)
            
            if removedItems.count <= addedItems.count || removedItems.count < commonItems.count {
                mediaWrapper = FileWrapper(directoryWithFileWrappers: container)
                
                let childReporter = ProgressReporter(totalUnitCount: removedItems.count + addedItems.count, parent: reporter)
                
                if !removedItems.isEmpty {
                    var index = 0
                    while index < removedItems.count {
                        let item = container.first{ $0.key == removedItems[index] }!
                        
                        mediaWrapper.removeFileWrapper(item.value)
                        Task {
                            await childReporter.advance()
                        }
                        
                        index += 1
                    }
                }
                
                if !addedItems.isEmpty {
                    let _newItems = snapshot.filter({ addedItems.contains($0.id.description + ".png" )})
                    let _newWrappers = _newItems.concurrent.map { item in
                        let image = item.image.data(using: .png)!
                        let imageWrapper = FileWrapper(regularFileWithContents: image)
                        imageWrapper.preferredFilename = "\(item.id).png"
                        
                        Task {
                            await childReporter.advance()
                        }
                        
                        return imageWrapper
                    }
                    
                    for wrapper in _newWrappers {
                        mediaWrapper.addFileWrapper(wrapper)
                    }
                }
                print("done")
            } else {
                let childReporter = ProgressReporter(totalUnitCount: snapshot.count, parent: reporter)
                
                let _newWrappers = snapshot.concurrent.map { item in
                    let image = item.image.data(using: .png)!
                    let imageWrapper = FileWrapper(regularFileWithContents: image)
                    imageWrapper.preferredFilename = "\(item.id).png"
                    
                    Task {
                        await childReporter.advance()
                    }
                    
                    return imageWrapper
                }
                
                for wrapper in _newWrappers {
                    mediaWrapper.addFileWrapper(wrapper)
                }
            }
        } else {
            print("performing save without old data")
            if configuration.contentType == .annotationProject {
                let childReporter = ProgressReporter(totalUnitCount: snapshot.count, parent: reporter)
                
                let _newWrappers = snapshot.concurrent.map { item in
                    let image = item.image.data(using: .png)!
                    let imageWrapper = FileWrapper(regularFileWithContents: image)
                    imageWrapper.preferredFilename = "\(item.id).png"
                    
                    Task {
                        await childReporter.advance()
                    }
                    
                    return imageWrapper
                }
                
                for wrapper in _newWrappers {
                    mediaWrapper.addFileWrapper(wrapper)
                }
            } else {
                let source = snapshot.filter { !$0.annotations.isEmpty }
                let childReporter = ProgressReporter(totalUnitCount: source.count, parent: reporter)
                
                let _newWrappers = source.concurrent.map { item in
                    let image = item.image.data(using: .png)!
                    let imageWrapper = FileWrapper(regularFileWithContents: image)
                    imageWrapper.preferredFilename = "\(item.id).png"
                    
                    Task {
                        await childReporter.advance()
                    }
                    
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
    
    fileprivate struct AnnotationExport: Codable {
        
        var id: UUID
        var image: String
        var annotations: [AnnotationImport.Annotations]
        
    }
    
    fileprivate struct AnnotationExportFolder: Codable {
        
        var image: String
        var annotations: [AnnotationImport.Annotations]
        
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
        let oldItems = annotations
        withAnimation {
            annotations.move(fromOffsets: offsets, toOffset: toOffset)
        }
        
        undoManager?.registerUndo(withTarget: self) { document in
            // Use the replaceItems symmetric undoable-redoable function.
            document.replaceItems(with: oldItems, undoManager: undoManager)
        }
        
    }
    
    /// Deletes the items at a specified set of offsets, and registers an undo action.
    func delete(offsets: IndexSet, undoManager: UndoManager? = nil) {
        let oldItems = annotations
        withAnimation {
            annotations.remove(atOffsets: offsets)
        }
        
        undoManager?.registerUndo(withTarget: self) { document in
            // Use the replaceItems symmetric undoable-redoable function.
            document.replaceItems(with: oldItems, undoManager: undoManager)
        }
    }
    
    /// Deletes the items, and registers an undo action.
    func delete(item: Annotation, undoManager: UndoManager?) {
        let oldItems = annotations
        withAnimation {
            annotations.removeAll(where: { $0 == item })
        }
        
        undoManager?.registerUndo(withTarget: self) { document in
            // Use the replaceItems symmetric undoable-redoable function.
            document.replaceItems(with: oldItems, undoManager: undoManager)
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
    
    func apply(undoManager: UndoManager?, oldItems: [Annotation]) {
        
        undoManager?.registerUndo(withTarget: self) { document in
            // Use the replaceItems symmetric undoable-redoable function.
            document.replaceItems(with: oldItems, undoManager: undoManager)
        }
    }
    
}


func loadItems(from sources: [FinderItem], reporter: ProgressReporter) async -> [Annotation] {
    
    var newItems: [Annotation] = []
    
    for source in sources {
        
        guard let contentType = source.contentType else { continue }
        
        switch contentType {
        case .annotationProject, .folder:
            guard let file = try? AnnotationDocument(from: FileWrapper(url: source.url, options: [])) else { fallthrough }
            newItems.append(contentsOf: file.annotations)
            await reporter.advance()
            
        case .folder:
            do {
                let wrapper = try FileWrapper(url: source.url, options: [])
                let mainWrapper = wrapper.fileWrappers!["annotations.json"]
                guard let value = mainWrapper?.regularFileContents else { fallthrough }
                let annotationImport = try JSONDecoder().decode([AnnotationImport].self, from: value)
                
                let childReporter = ProgressReporter(totalUnitCount: annotationImport.count, parent: reporter)
                
                let _newItems = await withTaskGroup(of: Annotation.self) { group in
                    for item in annotationImport {
                        group.addTask {
                            let annotation = Annotation(image: NSImage(at: source.with(subPath: item.image))!, annotations: item.annotations.map(\.annotations))
                            await childReporter.advance()
                            return annotation
                        }
                    }
                    
                    return await group.makeAsyncIterator().allObjects(reservingCapacity: annotationImport.count)
                }
                
                newItems.append(contentsOf: _newItems)
            } catch {
                print(error)
                fallthrough
            }
            
        case .folder:
            guard let children = source.children(range: .enumeration) else { continue }
            let childReporter = ProgressReporter(totalUnitCount: children.count, parent: reporter)
            
            let _newItems = await withTaskGroup(of: Annotation?.self) { group in
                for child in children {
                    group.addTask {
                        guard let image = child.image else { return nil }
                        let annotation = Annotation(image: image)
                        await childReporter.advance()
                        return annotation
                    }
                }
                
                return await group.makeAsyncIterator().allObjects(reservingCapacity: children.count).compacted()
            }
            
            newItems.append(contentsOf: _newItems)
            
        case .quickTimeMovie, .movie, .video, UTType("com.apple.m4v-video")!:
            guard let asset = AVAsset(at: source) else { fallthrough }
            guard let frameCount = asset.framesCount else { fallthrough }
            let childReporter = ProgressReporter(totalUnitCount: frameCount, parent: reporter)
            
            
            guard let frames = try? await asset.getFrames(onProgressChanged: { _ in
                Task {
                    await childReporter.advance()
                }
            }) else { continue }
            newItems.append(contentsOf: frames.map{ Annotation(id: UUID(), image: NativeImage(cgImage: $0), annotations: []) })
            
        default:
            guard let image = source.image else { continue }
            newItems.append(Annotation(id: UUID(), image: image, annotations: []))
        }
    }
    
    await reporter.complete()
    return newItems
}


struct AnnotationImport: Codable {
    
    let image: String
    let annotations: [Annotations]
    
    struct Annotations: Equatable, Hashable, Encodable, Decodable {
        
        var label: String
        var coordinates: Coordinate
        
        var annotations: Annotation.Annotations {
            return Annotation.Annotations(label: label, coordinates: Annotation.Annotations.Coordinate(x: coordinates.x, y: coordinates.y, width: coordinates.width, height: coordinates.height))
        }
        
        struct Coordinate: Equatable, Hashable, Encodable, Decodable {
            
            var x: Double
            var y: Double
            var width: Double
            var height: Double
            
        }
    }
    
}
