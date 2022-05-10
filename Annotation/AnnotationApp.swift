//
//  AnnotationApp.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import CoreML
import UniformTypeIdentifiers
import Support

@main
struct AnnotationApp: App {
    
    @State var document: AnnotationDocument = AnnotationDocument()
    @State var isShowingExportDialog = false
    @State var isShowingImportDialog = false
    @State var leftSideBarSelectedItem: Set<Annotation.ID> = []
    
    @State var isShowingModelDialog = false
    @State var model: MLModel? = nil
    @State var confidence = "0.8"
    
    @Environment(\.undoManager) var undoManager
    
    var body: some Scene {
        DocumentGroup(newDocument: { AnnotationDocument() }) { file in
            ContentView(leftSideBarSelectedItem: $leftSideBarSelectedItem)
                .onAppear {
                    self.document = file.document
                }
                .sheet(isPresented: $isShowingModelDialog) {
                    AutoaAnnotateView(isShowingModelDialog: $isShowingModelDialog, confidence: $confidence, model: $model, leftSideBarSelectedItem: $leftSideBarSelectedItem)
                }
        }
        .commands {
            CommandGroup(replacing: .importExport) {
                Section {
                    Button("Import") {
                        isShowingImportDialog = true
                    }
                    .keyboardShortcut("i")
                    .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.annotationProject, .movie, .quickTimeMovie, .folder, .image], allowsMultipleSelection: true) { result in
                        guard let urls = try? result.get() else { return }
                        Task.detached(priority: .background) {
                            print("import")
                            await document.addItems(from: urls, undoManager: undoManager)
                        }
                    }
                    
                    Button("Export...") {
                        isShowingExportDialog = true
                    }
                    .keyboardShortcut("e")
                    .fileExporter(isPresented: $isShowingExportDialog, document: document, contentType: .folder, defaultFilename: "Annotation Export") { result in
                        guard let url = try? result.get() else { return }
                        FinderItem(at: url)?.setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
                    }
                }
            }
            
            CommandGroup(after: .pasteboard) {
                Section {
                    Menu {
                        Button("based on model...") {
                            isShowingModelDialog.toggle()
                        }
                    } label: {
                        Text("Annotate")
                    }
                }
            }
        }
    }
}
