//
//  AppView.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import Stratum


struct AppView: View {
    
    @EnvironmentObject private var document: AnnotationDocument
    
    @Environment(\.undoManager) private var undoManager
    
    
    var body: some View {
        ContentView()
            .fileExporter(isPresented: $document.isShowingExportDialog, document: document, contentType: .folder, defaultFilename: "Annotation Export") { result in
                guard let url = try? result.get() else { return }
                Task.detached {
                    await FinderItem(at: url).setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
                }
            }
            .fileImporter(isPresented: $document.isShowingImportDialog, allowedContentTypes: [.annotationProject, .movie, .quickTimeMovie, .folder, .image], allowsMultipleSelection: true) { result in
                guard let urls = try? result.get().map({ FinderItem(at: $0) }) else { return }
                try! urls.tryAccessSecurityScope()
                nonisolated(unsafe)
                let oldItems = document.annotations
                
                Task { @MainActor in
                    document.isImporting = true
                    
                    do {
                        let newItems = try await loadItems(from: urls, reporter: document.importingProgress)
                        urls.stopAccessSecurityScope()
                        
                        let union = oldItems + newItems
                        
                        document.annotations = union
                        document.isImporting = false
                        
                        undoManager?.setActionName("import files")
                        undoManager?.registerUndo(withTarget: document, handler: { document in
                            document.replaceItems(with: oldItems, undoManager: undoManager)
                        })
                    } catch {
                        AlertManager(error).present()
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
