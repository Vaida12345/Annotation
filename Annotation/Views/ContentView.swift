//
//  ContentView.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import Cocoa
import Support

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
    
    
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        NavigationView {
            SideBar()
            
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
                .onChange(of: showLabelList) { newValue in
                    toggleSideBar(to: !newValue)
                    guard newValue else { return }
                    showInfoView = false
                    document.leftSideBarSelectedItem = []
                }
                .help("Show Label List")
            }
            
            ToolbarItem(placement: .navigation) {
                Group {
                    if document.isExporting {
                        ProgressView(value: document.exportingProgress)
                            .progressViewStyle(.circular)
                    } else if document.isImporting {
                        ProgressView(value: document.importingProgress)
                            .progressViewStyle(.circular)
                    }
                }
                .onTapGesture {
                    showPopover.toggle()
                }
                .popover(isPresented: $showPopover) {
                    VStack {
                        HStack {
                            Text(document.isImporting ? "Importing..." : "Exporting..")
                            
                            Spacer()
                        }
                        
                        ProgressView(value: document.isImporting ? document.importingProgress : document.exportingProgress)
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
                    FinderItem(at: url)?.setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
                }
            }
            
            ToolbarItem {
                Toggle(isOn: $showInfoView) {
                    Image(systemName: "list.bullet")
                }
                .help("Show Info View")
                .disabled(document.leftSideBarSelectedItem.count != 1)
            }
        }
    }
    
    var mainBody: some View {
        ZStack {
            if !document.annotations.isEmpty {
                if document.leftSideBarSelectedItem.isEmpty {
                    ContainerView {
                        Text("Select an item or items to start")
                    }
                } else {
                    DetailView()
                }
            } else {
                DropHandlerView()
                    .onDrop { sources in
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
                        
                        let union = oldItems + newItems
                        Task { @MainActor in
                            self.document.annotations = union
                            self.document.isImporting = false
                            
                            undoManager?.setActionName("import files")
                            undoManager?.registerUndo(withTarget: self.document, handler: { document in
                                document.replaceItems(with: oldItems, undoManager: undoManager)
                            })
                        }
                    }
            }
            
            if showInfoView, document.leftSideBarSelectedItem.count == 1, let selection = document.leftSideBarSelectedItem.first {
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
