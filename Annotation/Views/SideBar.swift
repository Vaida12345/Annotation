//
//  SideBar.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI


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
                autoreleasepool {
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
                                        for i in selection {
                                            document.annotations[document.annotations.firstIndex(where: { $0.id == i })!].annotations.removeAll(where: { $0.label == item })
                                        }
                                    }
                                }
                            } label: {
                                Text("Remove annotations")
                            }
                        }
                        .disabled(!selection.contains(annotation.id))
                }
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
            Task {
                for i in providers {
                    guard let result = try? await i.loadItem(forTypeIdentifier: "public.file-url", options: nil) else { return }
                    guard let urlData = result as? Data else { return }
                    guard let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                    await document.addItems(from: [url], undoManager: undoManager)
                }
            }
            return true
        }
        .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.annotationProject, .folder, .movie, .quickTimeMovie, .image], allowsMultipleSelection: true) { result in
            guard let urls = try? result.get() else { return }
            Task.detached(priority: .background) {
                await document.addItems(from: urls, undoManager: undoManager)
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
