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
