//
//  SideBar.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import FinderItem
import Essentials


struct SideBar: View {
    
    // core
    @Environment(AnnotationDocument.self) private var document
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        @Bindable var document = document
        ScrollViewReader { proxy in
            List(selection: $document.selectedItems) {
                ForEach(document.annotations) { annotation in
                    Image(nsImage: annotation.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(5)
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
                                            guard let index = document.annotations.firstIndex(where: { $0.id == i }) else { continue }
                                            document.annotations[index].annotations = []
                                        }
                                    }
                                }
                                
                                ForEach(document.annotations.filter({ document.selectedItems.contains($0.id) }).__labels, id: \.self) { item in
                                    Button(item) {
                                        undoManager?.setActionName("Remove annotation \"\(item)\" for selected items")
                                        document.apply(undoManager: undoManager) {
                                            for i in document.selectedItems {
                                                guard let index = document.annotations.firstIndex(where: { $0.id == i }) else { continue }
                                                document.annotations[index].annotations.removeAll(where: { $0.label == item })
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
                    document.isShowingImportDialog = true
                }
                .accessibilityLabel("Import files")
                .help("Import images, videos, folders, or annotation projects")
                
            }
            .frame(minWidth: 200)
            .dropDestination(for: FinderItem.self) { sources, location in
                guard !document.isImporting, !document.isExporting, !document.isReadOnly else { return false }
                Task { @MainActor in
                    document.startImport(from: sources, undoManager: undoManager)
                }
                return true
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
