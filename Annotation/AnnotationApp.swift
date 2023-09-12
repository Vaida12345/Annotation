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
    
    @State var isShowingAutoAnnotate = false
    @State var isShowingAutoDetect = false
    
    @State private var undoManager: UndoManager?
    @FocusedValue(\.document) var document
    
    var body: some Scene {
        DocumentGroup(newDocument: { AnnotationDocument() }) { file in
            ContentView()
                .withHostingWindow { window in
                    undoManager = window?.undoManager
                }
                .focusedSceneValue(\.document, file.document)
                .sheet(isPresented: $isShowingAutoAnnotate) {
                    AutoAnnotateView(undoManager: $undoManager)
                }
                .sheet(isPresented: $isShowingAutoDetect) {
                    AutoDetectView(undoManager: $undoManager)
                }
                .fileExporter(isPresented: $isShowingExportDialog, document: document, contentType: .folder, defaultFilename: "Annotation Export") { result in
                    guard let url = try? result.get() else { return }
                    FinderItem(at: url)?.setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
                }
                .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.annotationProject, .movie, .quickTimeMovie, .folder, .image], allowsMultipleSelection: true) { result in
                    guard let urls = try? result.get() else { return }
                    guard let document else { return }
                    Task.detached(priority: .background) {
                        let oldItems = await document.annotations
                        Task { @MainActor in
                            document.isImporting = true
                        }
                        
                        let newItems = try await loadItems(from: urls.map { FinderItem(at: $0) }, reporter: document.importingProgress)
                        
                        let union = oldItems + newItems
                        Task { @MainActor in
                            document.annotations = union
                            document.isImporting = false
                            
                            undoManager?.setActionName("import files")
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
            
            CommandMenu("Annotate") {
                Button("Based on model...") {
                    isShowingAutoAnnotate.toggle()
                }
                
                Button("Auto detect...") {
                    isShowingAutoDetect.toggle()
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


extension View {
    func withHostingWindow(_ callback: @escaping (_ window: NSWindow?) -> Void) -> some View {
        self.background(HostingWindowFinder(callback: callback))
    }
}

struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> ()
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) { }
}
