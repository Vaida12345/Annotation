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
    @Binding var selection: Set<Annotation.ID>
    @EnvironmentObject var document: AnnotationDocument
    
    // layout
    @State var isShowingImportDialog = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        
        List(selection: $selection) {
            ForEach(document.annotations) { annotation in
                Image(nsImage: annotation.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(5)
                    .contextMenu {
                        Button("Remove") {
                            document.apply(undoManager: undoManager) {
                                document.annotations.removeAll(where: { selection.contains($0.id) })
                            }
                            selection = []
                        }
                        
                        Menu {
                            Button("All") {
                                document.apply(undoManager: undoManager) {
                                    for i in selection {
                                        document.annotations[document.annotations.firstIndex(where: { $0.id == i })!].annotations = []
                                    }
                                }
                            }
                            
                            ForEach(document.annotations.filter({ selection.contains($0.id) }).labels, id: \.self) { item in
                                Button(item) {
                                    document.apply(undoManager: undoManager) {
                                        for i in selection {
                                            document.annotations[document.annotations.firstIndex(where: { $0.id == i })!].annotations.removeAll(where: { $0.label == item })
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text("Remove annotations")
                        }
                    }
                    .disabled(!selection.contains(annotation.id))
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
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    // It turned out that Appkit should be used to toggle sidebar
                    // https://sarunw.com/posts/how-to-toggle-sidebar-in-macos/
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers, location in
            Task.detached {
                
                let sources = try await [FinderItem](from: providers)
                
                Task { @MainActor in
                    self.document.isImporting = true
                }
                let oldItems = await document.annotations
                
                let reporter = ProgressReporter(totalUnitCount: sources.count) { progress in
                    Task { @MainActor in
                        self.document.importingProgress = progress
                    }
                }
                let newItems = await loadItems(from: sources, reporter: reporter)
                
                let union = oldItems.union(newItems)
                Task { @MainActor in
                    self.document.annotations = union
                    self.document.isImporting = false
                    
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
                
                let reporter = ProgressReporter(totalUnitCount: urls.count) { progress in
                    Task { @MainActor in
                        self.document.importingProgress = progress
                    }
                }
                let newItems = await loadItems(from: urls.map { FinderItem(at: $0) }, reporter: reporter)
                
                let union = oldItems.union(newItems)
                Task { @MainActor in
                    self.document.annotations = union
                    self.document.isImporting = false
                    
                    undoManager?.registerUndo(withTarget: self.document, handler: { document in
                        document.replaceItems(with: oldItems, undoManager: undoManager)
                    })
                }
            }
        }
        .onDeleteCommand {
            document.apply(undoManager: undoManager) {
                document.annotations.removeAll(where: { selection.contains($0.id) })
            }
            selection = []
        }
        
    }
}
