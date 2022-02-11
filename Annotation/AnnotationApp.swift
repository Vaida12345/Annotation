//
//  AnnotationApp.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI

@main
struct AnnotationApp: App {
    
    @State var file: AnnotationDocument = AnnotationDocument()
    @State var isShowingExportDialog = false
    @State var isShowingImportDialog = false
    
    var body: some Scene {
        DocumentGroup(newDocument: AnnotationDocument()) { file in
            DocumentView(document: file.$document)
                .onAppear {
                    self.file = file.document
                }
        }
        .commands {
            CommandGroup(replacing: .importExport) {
                Section {
                    Button("Import") {
                        isShowingImportDialog = true
                    }
                    .keyboardShortcut("i")
                    .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.annotationProject, .folder, .image], allowsMultipleSelection: true) { result in
                        guard let urls = try? result.get() else { return }
                        file.annotations.importForm(urls: urls)
                    }
                    
                    Button("Export...") {
                        isShowingExportDialog = true
                    }
                    .fileExporter(isPresented: $isShowingExportDialog, document: file, contentType: .folder, defaultFilename: "Annotation Export") { result in
                        guard let url = try? result.get() else { return }
                        FinderItem(at: url)?.setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
                    }
                }
            }
        }
    }
}


