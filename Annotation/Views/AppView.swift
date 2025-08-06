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
    
    @EnvironmentObject private var document: AnnotationDocument
    
    @Environment(\.undoManager) private var undoManager
    
    
    var body: some View {
        ContentView()
            .fileExporter(isPresented: $document.isShowingExportDialog, document: document, contentType: .folder, defaultFilename: "Annotation Export") { result in
                guard let url = try? result.get() else { return }
                FinderItem(at: url).setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
            }
            .fileImporter(isPresented: $document.isShowingImportDialog, allowedContentTypes: [.annotationProject, .movie, .quickTimeMovie, .folder, .image], allowsMultipleSelection: true) { result in
                guard let urls = try? result.get().map({ FinderItem(at: $0) }) else { return }
                try! urls.startAccessingSecurityScopedResource()
                nonisolated(unsafe)
                let oldItems = document.annotations
                
                Task { @MainActor in
                    document.isImporting = true
                    
                    await withErrorPresented("Failed to import") {
                        let newItems = try await loadItems(from: urls, reporter: document.importingProgress)
                        urls.stopAccessingSecurityScopedResource()
                        
                        let union = oldItems + newItems
                        
                        await MainActor.run {
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
            .sheet(isPresented: $document.isShowingAutoAnnotate) {
                AutoAnnotateView(undoManager: undoManager)
            }
            .sheet(isPresented: $document.isShowingAutoDetect) {
                AutoDetectView(globalUndoManager: undoManager)
            }
    }
}
