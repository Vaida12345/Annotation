//
//  ContentView.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import Cocoa
import ViewCollection
import FinderItem


struct ContentView: View {
    
    // core
    @State private var label = "label"
    @EnvironmentObject private var document: AnnotationDocument
    
    // layout
    @State private var showInfoView = false
    @State private var showLabelList = false
    @State private var showPopover = false
    @State private var sideBarState = true
    @State private var isShowingExportDialog = false
    
//    @State private var sideBarWidth = 0.0
    
    
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        NavigationView {
//            GeometryReader { geometry in
                SideBar()
//                    .onChange(of: geometry.size.width) { value in
//                        self.sideBarWidth = value
//                    }
//            }
            
            if showLabelList {
                LabelList(showLabelList: $showLabelList)
            } else {
                mainBody
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSideBar()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .disabled(showLabelList)
            }
            
            ToolbarItem(placement: .navigation) {
                Toggle(isOn: $showLabelList.animation()) {
                    Image(systemName: "rectangle.grid.3x2")
                }
                .onChange(of: showLabelList) { _, newValue in
                    toggleSideBar(to: !newValue)
                    
                    if newValue {
                        // show label list
                        showInfoView = false
                        document.previousSelectedItems = document.selectedItems
                        document.selectedItems = []
                    } else {
                        document.selectedItems = document.previousSelectedItems
                    }
                }
                .help("Show Label List")
            }
            
            ToolbarItem(placement: .navigation) {
                Group {
                    if document.isExporting {
                        ProgressView(document.exportingProgress)
                    } else if document.isImporting {
                        ProgressView(document.importingProgress)
                    }
                }
                .progressViewStyle(.circular())
                .onTapGesture {
                    showPopover.toggle()
                }
                .popover(isPresented: $showPopover) {
                    VStack {
                        HStack {
                            Text(document.isImporting ? "Importing..." : "Exporting..")
                            
                            Spacer()
                        }
                        .padding(.bottom)
                        
                        ProgressView(document.isImporting ? document.importingProgress : document.exportingProgress)
                    }
                    .padding()
                    .frame(width: 300)
                }
            }
            
            ToolbarItem {
                Button {
                    isShowingExportDialog = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .padding(.trailing)
                .fileExporter(isPresented: $isShowingExportDialog, document: document, contentType: .folder, defaultFilename: "Annotation Export") { result in
                    guard let url = try? result.get() else { return }
                    FinderItem(at: url).setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
                }
            }
            
            ToolbarItem {
                Toggle(isOn: $showInfoView) {
                    Image(systemName: "list.bullet")
                }
                .help("Show Info View")
                .disabled(document.selectedItems.count != 1)
            }
        }
    }
    
    var mainBody: some View {
        ZStack {
            if !document.annotations.isEmpty {
                if document.selectedItems.isEmpty {
                    ContainerView {
                        Text("Select an item or items to start")
                            .foregroundStyle(.gray)
                            .fontDesign(.rounded)
                            .fontWeight(.heavy)
                            .font(.title3)
                    }
                } else {
                    DetailView()
                }
            } else {
                DropHandlerView()
                    .onDrop { sources in
                        try? sources.startAccessingSecurityScopedResource()
                        Task {
                            defer { sources.stopAccessingSecurityScopedResource() }
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
                    }
            }
            
            if showInfoView, document.selectedItems.count == 1, let selection = document.selectedItems.first {
                HStack {
                    Spacer()
                    if let first = $document.annotations.first(where: {$0.id == selection}) {
                        InfoView(annotation: first)
                            .frame(width: 300)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            }
        }
    }
    
    func toggleSideBar(to state: Bool? = nil) {
        if let state, state == sideBarState { return }
        
        // It turned out that Appkit should be used to toggle sidebar
        // https://sarunw.com/posts/how-to-toggle-sidebar-in-macos/
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        sideBarState.toggle()
    }
    
}
