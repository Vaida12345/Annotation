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
    
    @State var isShowingExportDialog = false
    @State var isShowingImportDialog = false
    @State var leftSideBarSelectedItem: Set<Annotation.ID> = []
    
    @State var isShowingModelDialog = false
    @State var model: MLModel? = nil
    @State var confidence = "0.8"
    
    @Environment(\.undoManager) var undoManager
    @FocusedValue(\.document) var document
    
    var body: some Scene {
        DocumentGroup(newDocument: { AnnotationDocument() }) { file in
            ContentView(leftSideBarSelectedItem: $leftSideBarSelectedItem)
                .focusedSceneValue(\.document, file.document)
                .sheet(isPresented: $isShowingModelDialog) {
                    AutoaAnnotateView(isShowingModelDialog: $isShowingModelDialog, confidence: $confidence, model: $model, leftSideBarSelectedItem: $leftSideBarSelectedItem)
                }
                .fileExporter(isPresented: $isShowingExportDialog, document: document, contentType: .folder, defaultFilename: "Annotation Export") { result in
                    guard let url = try? result.get() else { return }
                    FinderItem(at: url)?.setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
                }
                .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.annotationProject, .movie, .quickTimeMovie, .folder, .image], allowsMultipleSelection: true) { result in
                    guard let urls = try? result.get() else { return }
                    guard let document else { return }
                    Task.detached(priority: .background) {
                        let oldItems = document.annotations
                        Task { @MainActor in
                            document.isImporting = true
                        }
                        
                        let reporter = ProgressReporter(totalUnitCount: urls.count) { progress in
                            Task { @MainActor in
                                document.importingProgress = progress
                            }
                        }
                        let newItems = await loadItems(from: urls.map { FinderItem(at: $0) }, reporter: reporter)
                        
                        let union = oldItems.union(newItems)
                        Task { @MainActor in
                            document.annotations = union
                            document.isImporting = false
                            
                            undoManager?.registerUndo(withTarget: document, handler: { document in
                                document.replaceItems(with: oldItems, undoManager: undoManager)
                            })
                        }
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .importExport) {
                Section {
                    Button("Import") {
                        isShowingImportDialog = true
                    }
                    .keyboardShortcut("i")
                    
                    Button("Export...") {
                        isShowingExportDialog = true
                    }
                    .keyboardShortcut("e")
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


extension FocusedValues {
    struct DocumentFocusedValues: FocusedValueKey {
        typealias Value = AnnotationDocument
    }
    
    var document: AnnotationDocument? {
        get {
            self[DocumentFocusedValues.self]
        }
        set {
            self[DocumentFocusedValues.self] = newValue
        }
    }
}
