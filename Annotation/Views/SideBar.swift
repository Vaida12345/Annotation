//
//  SideBar.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import FinderItem
import ViewCollection


struct SideBar: View {
    
    // core
    @EnvironmentObject var document: AnnotationDocument
    
    // layout
    @State var isShowingImportDialog = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $document.selectedItems) {
                ForEach(document.annotations) { annotation in
                    AsyncView {
                        annotation.representation.image
                    } content: { result in
                        Image(nsImage: result)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(5)
                    }
                    .contextMenu {
                        Button("Remove") {
                            undoManager?.beginUndoGrouping()
                            for id in document.selectedItems {
                                document.removeAnnotation(undoManager: undoManager, annotationID: id)
                            }
                            undoManager?.endUndoGrouping()
                            undoManager?.setActionName("Remove images")
                            document.selectedItems = []
                        }
                        
                        Menu {
                            Button("All") {
                                undoManager?.setActionName("Remove all annotations for selected items")
                                document.apply(undoManager: undoManager) {
                                    for i in document.selectedItems {
                                        document.annotations[document.annotations.firstIndex(where: { $0.id == i })!].annotations = []
                                    }
                                }
                            }
                            
                            ForEach(document.annotations.filter({ document.selectedItems.contains($0.id) }).__labels, id: \.self) { item in
                                Button(item) {
                                    undoManager?.setActionName("Remove annotation \"\(item)\" for selected items")
                                    document.apply(undoManager: undoManager) {
                                        for i in document.selectedItems {
                                            document.annotations[document.annotations.firstIndex(where: { $0.id == i })!].annotations.removeAll(where: { $0.label == item })
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text("Remove annotations")
                        }
                    }
                    .disabled(!document.selectedItems.contains(annotation.id))
                    .id(annotation.id)
                }
                .onMove { fromIndex, toIndex in
                    document.moveItemsAt(offsets: fromIndex, toOffset: toIndex, undoManager: undoManager)
                }
                .onDelete { index in
                    document.delete(offsets: index, undoManager: undoManager)
                }
                
                GroupBox {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "plus")
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .onTapGesture {
                    isShowingImportDialog = true
                }
                
            }
            .frame(minWidth: 200)
            .dropDestination(for: FinderItem.self) { sources, location in
                let sources = sources
                try? sources.startAccessingSecurityScopedResource()
                
                Task.detached {
                    defer { sources.stopAccessingSecurityScopedResource() }
                    
                    Task { @MainActor in
                        self.document.isImporting = true
                    }
                    nonisolated(unsafe) let oldItems = await document.annotations
                    let newItems = try await loadItems(from: sources, reporter: self.document.importingProgress)
                    
                    let union = oldItems + newItems
                    Task { @MainActor in
                        self.document.annotations = union
                        self.document.isImporting = false
                        
                        if newItems.count == 1 { self.document.selectedItems = [newItems.first!.id] }
                        
                        undoManager?.setActionName("import files")
                        undoManager?.registerUndo(withTarget: self.document, handler: { document in
                            document.replaceItems(with: oldItems, undoManager: undoManager)
                        })
                    }
                }
                return true
            }
            .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.annotationProject, .folder, .movie, .quickTimeMovie, .image], allowsMultipleSelection: true) { result in
                guard let urls = try? result.get().map ({ FinderItem(at: $0) }) else { return }
                try? urls.startAccessingSecurityScopedResource()
                
                Task.detached {
                    defer { urls.stopAccessingSecurityScopedResource() }
                    
                    let oldItems = await document.annotations
                    Task { @MainActor in
                        self.document.isImporting = true
                    }
                    
                    let newItems = try await loadItems(from: urls, reporter: self.document.importingProgress)
                    
                    let union = oldItems + newItems
                    Task { @MainActor in
                        self.document.annotations = union
                        self.document.isImporting = false
                        
                        if newItems.count == 1 { self.document.selectedItems = [newItems.first!.id] }
                        
                        undoManager?.setActionName("import files")
                        undoManager?.registerUndo(withTarget: self.document, handler: { document in
                            document.replaceItems(with: oldItems, undoManager: undoManager)
                        })
                    }
                }
            }
            .onDeleteCommand {
                let sequence = document.annotations.indices(where: { document.selectedItems.contains($0.id) })
                let indexSet = sequence.ranges.flatten()
                document.delete(offsets: IndexSet(indexSet), undoManager: undoManager)
                
                document.selectedItems = []
            }
            .onAppear {
                document.scrollProxy = proxy
            }
        }
    }
}
