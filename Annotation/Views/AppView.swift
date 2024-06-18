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
                guard let urls = try? result.get() else { return }
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
            .sheet(isPresented: $document.isShowingAutoAnnotate) {
                AutoAnnotateView(undoManager: undoManager)
            }
            .sheet(isPresented: $document.isShowingAutoDetect) {
                AutoDetectView(globalUndoManager: undoManager)
            }
    }
}
