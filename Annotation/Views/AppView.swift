//
//  AppView.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import FinderItem
import Essentials


struct AppView: View {
    
    @Environment(AnnotationDocument.self) private var document
    
    @Environment(\.undoManager) private var undoManager
    
    
    var body: some View {
        @Bindable var document = document
        ContentView()
            .fileExporter(isPresented: $document.isShowingExportDialog, document: document, contentType: .folder, defaultFilename: "Annotation Export") { result in
                guard let url = try? result.get() else { return }
                if #available(macOS 26, *) {
                    try? FinderItem(at: url).setIcon(image: FinderItem.bundleItem(forResource: "folder_26", withExtension: "icns").load(.image))
                } else {
                    try? FinderItem(at: url).setIcon(image: FinderItem.bundleItem(forResource: "folder_15", withExtension: "icns").load(.image))
                }
            }
            .fileImporter(isPresented: $document.isShowingImportDialog, allowedContentTypes: [.annotationProject, .movie, .quickTimeMovie, .folder, .image], allowsMultipleSelection: true) { result in
                guard let urls = try? result.get().map({ FinderItem(at: $0) }) else { return }
                let oldItems = document.annotations
                
                Task { @MainActor in
                    document.isImporting = true
                    
                    await withErrorPresented("Failed to load files") {
                        defer { document.isImporting = false }
                        try urls.startAccessingSecurityScopedResource()
                        defer { urls.stopAccessingSecurityScopedResource() }
                        
                        let newItems = try await loadItems(from: urls, reporter: document.importingProgress)
                        
                        let union = oldItems + newItems
                        
                        await MainActor.run {
                            document.annotations = union
                            
                            undoManager?.setActionName("import files")
                            undoManager?.registerUndo(withTarget: document, handler: { document in
                                document.replaceItems(with: oldItems, undoManager: undoManager)
                            })
                        }
                    }
                }
            }
            .sheet(isPresented: $document.isShowingAutoAnnotate) {
                AutoAnnotateView(undoManager: undoManager)
            }
            .sheet(isPresented: $document.isShowingAutoDetect) {
                AutoDetectView(globalUndoManager: undoManager)
            }
            .alert("Some project entries could not be opened", isPresented: Binding(
                get: { !document.loadWarnings.isEmpty },
                set: { if !$0 { document.loadWarnings.removeAll() } }
            )) {
                Button("OK") { document.loadWarnings.removeAll() }
            } message: {
                Text(loadWarningMessage)
            }
    }

    private var loadWarningMessage: String {
        let count = document.loadWarnings.count
        let details = document.loadWarnings.prefix(8).joined(separator: "\n")
        let remainder = count > 8 ? "\n…and \(count - 8) more." : ""
        return "\(count) \(count == 1 ? "entry was" : "entries were") skipped. The remaining project content was recovered.\n\n\(details)\(remainder)"
    }
}
