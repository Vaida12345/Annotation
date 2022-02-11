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
                    
                    Button("Export…") {
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
