//
//  AnnotationDocument.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import UniformTypeIdentifiers
import Support

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

    static var readableContentTypes: [UTType] { [.annotationProject] }
    static var writableContentTypes: [UTType] { [.annotationProject, .folder] }
    
    init(from wrapper: FileWrapper) throws {
        let mainWrapper = wrapper.fileWrappers!["annotations.json"]
        guard let mediaFileWrapper = wrapper.fileWrappers!["Media"] else { throw CocoaError(.fileReadCorruptFile) }
        guard let data = mainWrapper?.regularFileContents,
              let document = try? JSONDecoder().decode([AnnotationExport].self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // create Annotation
        let id = UUID()
        var annotations = [Annotation](repeating: Annotation(id: id, image: NSImage(), annotations: []), count: document.count)
        let container = mediaFileWrapper.fileWrappers!
        
        DispatchQueue.concurrentPerform(iterations: document.count) { index in
            autoreleasepool {
                let documentItem = document[index]
                guard let mediaItem = container["\(documentItem.id.description).png"] else { return }
                let image = NSImage(data: mediaItem.regularFileContents!)!
                
                DispatchQueue.main.sync {
                    print("\(index) / \(document.count)")
                    annotations[index] = Annotation(id: documentItem.id, image: image, annotations: documentItem.annotations.map({ $0.annotations }))
                }
            }
        }
        annotations.removeAll(where: { $0.id == id })
        self.annotations = annotations
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
        let exporter = DispatchQueue.main
        
        exporter.async {
            self.isExporting = true
            self.exportingProgress = 0.0
        }
        
        var data: Data
        
        if configuration.contentType == .annotationProject {
            var annotationsExport: [AnnotationExport] = []
            var index = 0
            while index < snapshot.count {
                let i = snapshot[index]
                annotationsExport.append(AnnotationExport(id: i.id, image: "Media/\(i.id.description).png", annotations: i.annotations.map{ $0.export }))
                index += 1
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            data = try encoder.encode(annotationsExport)
        } else {
            // create AnnotationDocument.AnnotationExport
            var annotationsExport: [AnnotationExportFolder] = []
            var index = 0
            while index < snapshot.count {
                let i = snapshot[index]
                guard !i.annotations.isEmpty else { index += 1; continue }
                annotationsExport.append(AnnotationExportFolder(image: "Media/\(i.id.description).png", annotations: i.annotations.map{ $0.export }))
                index += 1
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            data = try encoder.encode(annotationsExport)
        }
        
        exporter.async {
            self.exportingProgress = 0.1
        }
        
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        let mainWrapper = FileWrapper(regularFileWithContents: data)
        mainWrapper.preferredFilename = "annotations.json"
        wrapper.addFileWrapper(mainWrapper)
        
        var mediaWrapper = FileWrapper(directoryWithFileWrappers: [:])
        mediaWrapper.preferredFilename = "Media"
        
        if let existingFile = configuration.existingFile, let container = existingFile.fileWrappers!["Media"]?.fileWrappers, configuration.contentType == .annotationProject {
            
            let oldItems = Array(container.keys)
            let newItems = snapshot.map{ $0.id.description + ".png" }
            let commonItems = oldItems.intersection(newItems)
            var addedItems = newItems
            addedItems.removeAll(where: { commonItems.contains($0) })
            var removedItems = oldItems
            removedItems.removeAll(where: { commonItems.contains($0) })
            
            print("result", commonItems.count, addedItems.count, removedItems.count)
            
            if removedItems.count <= addedItems.count || removedItems.count < commonItems.count {
                
                exporter.async {
                    mediaWrapper = FileWrapper(directoryWithFileWrappers: container)
                    mediaWrapper.preferredFilename = "Media"
                    wrapper.addFileWrapper(mediaWrapper)
                }
                
                
                if !removedItems.isEmpty {
                    var index = 0
                    let stepper = 0.9 / Double(removedItems.count)
                    while index < removedItems.count {
                        autoreleasepool {
                            let item = container.filter({ $0.key == removedItems[index] }).first!
                            exporter.async {
                                mediaWrapper.removeFileWrapper(item.value)
                                self.exportingProgress += stepper
                            }
                            
                            index += 1
                            
                        }
                    }
                }
                
                if !addedItems.isEmpty {
                    let stepper = 0.9 / Double(snapshot.filter({ addedItems.contains($0.id.description + ".png" )}).count)
                    DispatchQueue.concurrentPerform(iterations: snapshot.filter({ addedItems.contains($0.id.description + ".png" )}).count) { index  in
                        autoreleasepool {
                            let item = snapshot.filter({ addedItems.contains($0.id.description + ".png" ) })[index]
                            
                            let image = item.image
                            let imageWrapper = FileWrapper(regularFileWithContents: NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!)
                            imageWrapper.preferredFilename = "\(item.id).png"
                            
                            print(index)
                            exporter.async {
                                mediaWrapper.addFileWrapper(imageWrapper)
                                self.exportingProgress += stepper
                            }
                        }
                    }
                }
                print("done")
            } else {
                let stepper = 0.9 / Double(snapshot.count)
                DispatchQueue.concurrentPerform(iterations: snapshot.count) { index in
                    autoreleasepool {
                        let item = snapshot[index]
                        let image = item.image
                        let imageWrapper = FileWrapper(regularFileWithContents: NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!)
                        imageWrapper.preferredFilename = "\(item.id).png"
                        print(index)
                        
                        exporter.async {
                            mediaWrapper.addFileWrapper(imageWrapper)
                            self.exportingProgress += stepper
                        }
                    }
                }
            }
        } else {
            print("performing save without old data")
            wrapper.addFileWrapper(mediaWrapper)
            if configuration.contentType == .annotationProject {
                let stepper = 0.9 / Double(snapshot.count)
                DispatchQueue.concurrentPerform(iterations: snapshot.count) { index in
                    autoreleasepool {
                        let item = snapshot[index]
                        let image = item.image
                        let imageWrapper = FileWrapper(regularFileWithContents: NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!)
                        imageWrapper.preferredFilename = "\(item.id).png"
                        
                        exporter.async {
                            mediaWrapper.addFileWrapper(imageWrapper)
                            self.exportingProgress += stepper
                        }
                    }
                }
            } else {
                let stepper = 0.9 / Double(snapshot.count)
                DispatchQueue.concurrentPerform(iterations: snapshot.count) { index in
                    autoreleasepool {
                        let item = snapshot[index]
                        guard !item.annotations.isEmpty else {
                            exporter.async {
                                self.exportingProgress += stepper
                            }
                            return
                        }
                        let image = item.image
                        let imageWrapper = FileWrapper(regularFileWithContents: NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!)
                        imageWrapper.preferredFilename = "\(item.id).png"
                        
                        exporter.async {
                            mediaWrapper.addFileWrapper(imageWrapper)
                            self.exportingProgress += stepper
                        }
                    }
                }
            }
        }
        
        print("here")
        exporter.sync {
            mediaWrapper.preferredFilename = "Media"
            self.isExporting = false
            self.exportingProgress = 1.0
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
    
    func addItems(from urls: [URL?], undoManager: UndoManager?) async {
        
        DispatchQueue.main.async {
            self.isImporting = true
            self.importingProgress = 0.0
        }
        
        let oldItems = annotations
        var newItems: [Annotation] = []
        
        for i in urls {
            guard let item = FinderItem(at: i) else { continue }
            guard item.type != nil else { continue }
            
            switch item.type! {
            case .annotationProject, .folder:
                guard let file = try? AnnotationDocument(from: FileWrapper(url: item.url, options: [])) else { fallthrough }
                newItems.append(contentsOf: file.annotations)
                
            case .folder:
                do {
                    let wrapper = try FileWrapper(url: item.url, options: [])
                    let mainWrapper = wrapper.fileWrappers!["annotations.json"]
                    guard let value = mainWrapper?.regularFileContents else { fallthrough }
                    let annotationImport = try JSONDecoder().decode([AnnotationImport].self, from: value)
                    newItems.append(contentsOf: annotationImport.map{
                        DispatchQueue.main.async {
                            self.importingProgress += 1 / Double(annotationImport.count)
                        }
                        return Annotation(id: UUID(), image: FinderItem(at: item.url.path + "/" + $0.image).image!, annotations: $0.annotations.map{ $0.annotations })
                    })
                } catch {
                    fallthrough
                }
                
            case .folder:
                item.iterated { child in
                    guard let image = child.image else { return }
                    DispatchQueue.main.async {
                        self.importingProgress += 1 / Double(item.children(range: .enumeration)!.count)
                    }
                    newItems.append(Annotation(id: UUID(), image: image, annotations: []))
                }
                
            case .quickTimeMovie, .movie, .video, UTType("com.apple.m4v-video")!:
                guard let frames = await item.avAsset?.getFrames() else { return }
                newItems.append(contentsOf: frames.map{ Annotation(id: UUID(), image: $0, annotations: []) })
                
            default:
                guard let image = item.image else { return }
                newItems.append(Annotation(id: UUID(), image: image, annotations: []))
            }
        }
        
        withAnimation {
            annotations.formUnion(newItems)
        }
        
        DispatchQueue.main.async {
            self.isImporting = false
            self.importingProgress = 1.0
        }
        
        undoManager?.registerUndo(withTarget: self, handler: { document in
            document.replaceItems(with: oldItems, undoManager: undoManager)
        })
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
