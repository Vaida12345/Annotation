//
//  AnnotationDocument.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var annotationProject: UTType {
        UTType(importedAs: "com.Vaida.annotation-project")
    }
}

final class AnnotationDocument: ReferenceFileDocument {
    
    typealias Snapshot = Array<Annotation>
    
    @Published var annotations: [Annotation]

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
        var annotations: [Annotation] = []
        for i in 0..<document.count {
            let documentItem = document[i]
            let mediaItem = mediaFileWrapper.fileWrappers!["\(documentItem.id.description).png"]!
            
            annotations.append(Annotation(id: documentItem.id, image: NSImage(data: mediaItem.regularFileContents!)!, annotations: documentItem.annotations))
        }
        
        self.annotations = annotations
    }

    convenience init(configuration: ReadConfiguration) throws {
        let wrapper = configuration.file
        try self.init(from: wrapper)
    }
    
    func snapshot(contentType: UTType) throws -> [Annotation] {
        annotations
    }
    
    func fileWrapper(snapshot: [Annotation], configuration: WriteConfiguration) throws -> FileWrapper {
        // create AnnotationDocument.AnnotationExport
        var annotationsExport: [AnnotationExport] = []
        for i in snapshot {
            annotationsExport.append(AnnotationExport(id: i.id, image: "Media/\(i.id.description).png", annotations: i.annotations))
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(annotationsExport)
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        let mainWrapper = FileWrapper(regularFileWithContents: data)
        mainWrapper.preferredFilename = "annotations.json"
        wrapper.addFileWrapper(mainWrapper)
        
        let mediaWrapper = FileWrapper(directoryWithFileWrappers: [:])
        mediaWrapper.preferredFilename = "Media"
        wrapper.addFileWrapper(mediaWrapper)
        
        for index in 0..<annotations.count {
            let item = annotations[index]
            let image = item.image
            let imageWrapper = FileWrapper(regularFileWithContents: NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!)
            imageWrapper.preferredFilename = "\(item.id).png"
            
            mediaWrapper.addFileWrapper(imageWrapper)
        }
        
        return wrapper
    }
    
    struct AnnotationExport: Codable {
        
        var id: UUID
        var image: String
        var annotations: [Annotation.Annotations]
        
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
    
    func addItems(from urls: [URL?], undoManager: UndoManager?) {
        
        let oldItems = annotations
        var newItems: [Annotation] = []
        
        for i in urls {
            guard let item = FinderItem(at: i) else { continue }
            guard item.type != nil else { continue }
            
            switch item.type! {
            case .annotationProject, .folder:
                guard let file = try? AnnotationDocument(from: FileWrapper(url: item.url, options: [])) else { fallthrough }
                newItems.formUnion(file.annotations)
                
            case .folder:
                do {
                    let wrapper = try FileWrapper(url: item.url, options: [])
                    let mainWrapper = wrapper.fileWrappers!["annotations.json"]
                    guard let value = mainWrapper?.regularFileContents else { fallthrough }
                    let annotationImport = try JSONDecoder().decode([AnnotationImport].self, from: value)
                    newItems.formUnion(annotationImport.map{ Annotation(id: UUID(), image: FinderItem(at: item.url.path + "/" + $0.image).image!, annotations: $0.annotations) })
                } catch {
                    fallthrough
                }
                
            case .folder:
                item.iteratedOver { child in
                    guard let image = child.image else { return }
                    newItems.append(Annotation(id: UUID(), image: image, annotations: []))
                }
                
            case .quickTimeMovie:
                guard let frames = item.frames else { return }
                newItems.formUnion(frames.map{ Annotation(id: UUID(), image: $0, annotations: []) })
                
            default:
                guard let image = item.image else { return }
                newItems.append(Annotation(id: UUID(), image: image, annotations: []))
            }
        }
        
        withAnimation {
            annotations.formUnion(newItems)
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
    
    func apply(action: (()->Void), undoManager: UndoManager?) {
        let oldItems = annotations
        withAnimation {
            action()
        }
        
        undoManager?.registerUndo(withTarget: self) { document in
            // Use the replaceItems symmetric undoable-redoable function.
            document.replaceItems(with: oldItems, undoManager: undoManager)
        }
    }
    
    
}


private struct AnnotationImport: Codable {
    
    let image: String
    let annotations: [Annotation.Annotations]
    
}
