//
//  SideBar.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import Support


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
                    Image(nsImage: annotation.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(5)
                        .contextMenu {
                            Button("Remove") {
                                undoManager?.setActionName("Remove images")
                                undoManager?.beginUndoGrouping()
                                for id in document.selectedItems {
                                    document.removeAnnotation(undoManager: undoManager, annotationID: id)
                                }
                                undoManager?.endUndoGrouping()
                                document.selectedItems = []
                            }
                            
                            Menu {
                                Button("All") {
                                    undoManager?.setActionName("Remove all annotations")
                                    document.apply(undoManager: undoManager) {
                                        for i in document.selectedItems {
                                            document.annotations[document.annotations.firstIndex(where: { $0.id == i })!].annotations = []
                                        }
                                    }
                                }
                                
                                ForEach(document.annotations.filter({ document.selectedItems.contains($0.id) }).__labels, id: \.self) { item in
                                    Button(item) {
                                        undoManager?.setActionName("Remove annotation \"\(item)\"")
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
            .onDrop(of: [.fileURL], isTargeted: nil) { providers, location in
                Task.detached {
                    
                    let sources = try await [FinderItem](from: providers)
                    
                    Task { @MainActor in
                        self.document.isImporting = true
                    }
                    let oldItems = await document.annotations
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
                guard let urls = try? result.get() else { return }
                Task.detached(priority: .background) {
                    let oldItems = await document.annotations
                    Task { @MainActor in
                        self.document.isImporting = true
                    }
                    
                    let newItems = try await loadItems(from: urls.map { FinderItem(at: $0) }, reporter: self.document.importingProgress)
                    
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
                let sequence = document.annotations.indexes(where: { document.selectedItems.contains($0.id) })
                let indexSet = IndexSet(sequence)
                document.delete(offsets: indexSet, undoManager: undoManager)
                
                document.selectedItems = []
            }
            .onAppear {
                document.scrollProxy = proxy
            }
        }
    }
}
