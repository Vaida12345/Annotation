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
import Essentials


struct ContentView: View {
    
    // core
    @State private var label = "label"
    @Bindable var document: AnnotationDocument
    
    // layout
    @State private var showInfoView = false
    @State private var showLabelList = false
    @State private var showPopover = false
    @State private var sideBarState = true
    
    
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
                    if document.isImporting {
                        ProgressView(document.importingProgress)
                    } else if document.isExporting {
                        ProgressView(document.exportingProgress)
                    }
                }
                .progressViewStyle(.circular())
                .onTapGesture {
                    if document.isImporting || document.isExporting { showPopover.toggle() }
                }
                .popover(isPresented: $showPopover) {
                    VStack {
                        HStack {
                            Text(document.isImporting ? "Importing…" : "Exporting…")
                            
                            Spacer()

                            if document.isImporting {
                                Button("Cancel") { document.cancelImport() }
                            }
                        }
                        .padding(.bottom)
                        
                        ProgressView(document.isImporting ? document.importingProgress : document.exportingProgress)
                    }
                    .padding()
                    .frame(width: 300)
                }
                .onChange(of: document.isImporting) { _, isImporting in
                    if !isImporting && !document.isExporting { showPopover = false }
                }
                .onChange(of: document.isExporting) { _, isExporting in
                    if !isExporting && !document.isImporting { showPopover = false }
                }
            }
            
            ToolbarItem {
                Button {
                    document.isShowingExportDialog = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .padding(.trailing)
                .disabled(document.isImporting || document.isExporting || document.isReadOnly)
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
    
    @ViewBuilder
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
                        Task { @MainActor in
                            document.startImport(from: sources, undoManager: undoManager)
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
