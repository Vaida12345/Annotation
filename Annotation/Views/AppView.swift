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
    
    @Bindable var document: AnnotationDocument
    
    @Environment(\.undoManager) private var undoManager

    @State private var recoveryExportDocument: AnnotationDocument?
    
    
    var body: some View {
        VStack(spacing: 0) {
            if document.isReadOnly {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Recovered project — read-only")
                    Spacer()
                    Text("Some entries could not be opened.")
                        .foregroundStyle(.secondary)
                    Button("Save Recovered Copy…") {
                        recoveryExportDocument = document.recoveredCopy()
                        document.isShowingRecoverySaveDialog = true
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.yellow.opacity(0.18))
            }
            
            ContentView(document: document)
                .disabled(document.isReadOnly)
        }
        .fileExporter(
            isPresented: isShowingFileExporter,
            document: recoveryExportDocument ?? document,
            contentType: recoveryExportDocument == nil ? .folder : .annotationProject,
            defaultFilename: recoveryExportDocument == nil ? "Annotation Export" : "Recovered Annotation Project"
        ) { result in
            Task { @MainActor in
                let isRecoveryExport = recoveryExportDocument != nil
                defer {
                    if isRecoveryExport {
                        recoveryExportDocument = nil
                    }
                }
                withErrorPresented(isRecoveryExport ? "Failed to save recovered project" : "Failed to export") {
                    let url: URL
                    do {
                        url = try result.get()
                    } catch let error as CocoaError where error.code == .userCancelled {
                        return
                    }
                    if !isRecoveryExport {
                        if #available(macOS 26, *) {
                            try? FinderItem(at: url).setIcon(image: FinderItem.bundleItem(forResource: "folder_26", withExtension: "icns").load(.image))
                        } else {
                            try? FinderItem(at: url).setIcon(image: FinderItem.bundleItem(forResource: "folder_15", withExtension: "icns").load(.image))
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $document.isShowingImportDialog, allowedContentTypes: [.annotationProject, .movie, .quickTimeMovie, .folder, .image], allowsMultipleSelection: true) { result in
            Task { @MainActor in
                withErrorPresented("Failed to load files") {
                    let urls: [URL]
                    do {
                        urls = try result.get()
                    } catch let error as CocoaError where error.code == .userCancelled {
                        return
                    }
                    let sources = urls.map(FinderItem.init(at:))
                    document.startImport(from: sources, undoManager: undoManager)
                }
            }
        }
        .sheet(isPresented: $document.isShowingAutoAnnotate) {
            AutoAnnotateView(undoManager: undoManager)
        }
        .sheet(isPresented: $document.isShowingAutoDetect) {
            AutoDetectView(globalUndoManager: undoManager)
        }
        .alert("Some project entries could not be opened", isPresented: $document.isShowingRecoveryWarning) {
            Button("Save Recovered Copy…") {
                recoveryExportDocument = document.recoveredCopy()
                document.isShowingRecoverySaveDialog = true
            }
            Button("OK") { document.isShowingRecoveryWarning = false }
        } message: {
            Text(loadWarningMessage)
        }
    }

    private var isShowingFileExporter: Binding<Bool> {
        Binding(
            get: {
                document.isShowingExportDialog || document.isShowingRecoverySaveDialog
            },
            set: { isPresented in
                if !isPresented {
                    document.isShowingExportDialog = false
                    document.isShowingRecoverySaveDialog = false
                }
            }
        )
    }
    
    private var loadWarningMessage: String {
        let count = document.loadWarnings.count
        let details = document.loadWarnings.prefix(8).joined(separator: "\n")
        let remainder = count > 8 ? "\n…and \(count - 8) more." : ""
        return "\(count) \(count == 1 ? "entry was" : "entries were") skipped. The remaining project content was recovered in read-only mode to protect the original package.\n\n\(details)\(remainder)"
    }
}
