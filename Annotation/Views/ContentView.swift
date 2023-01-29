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
    @Binding var leftSideBarSelectedItem: Set<Annotation.ID>
    @State private var showInfoView = false
    @State private var showLabelList = false
    @State private var showPopover = false
    
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        NavigationView {
            SideBar(selection: $leftSideBarSelectedItem)
            
            ZStack {
                if !document.annotations.isEmpty {
                    DetailView(leftSideBarSelectedItem: $leftSideBarSelectedItem)
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
                
                if leftSideBarSelectedItem.count == 1, let selection = leftSideBarSelectedItem.first {
                    if showInfoView {
                        HStack {
                            Spacer()
                            if document.annotations.first(where: {$0.id == selection}) != nil {
                                InfoView(annotation: $document.annotations.first(where: {$0.id == selection})!)
                                    .frame(width: 300)
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                    } else if showLabelList {
                        HStack {
                            Spacer()
                            LabelList(leftSideBarSelectedItem: $leftSideBarSelectedItem)
                                .frame(width: 300)
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                    }
                }
            }
            .toolbar {
                
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
                
                Toggle(isOn: $showLabelList) {
                    Image(systemName: "tag")
                }
                .onChange(of: showLabelList) { newValue in
                    guard newValue else { return }
                    showInfoView = false
                }
                .help("Show Label List")
                .disabled(leftSideBarSelectedItem.count != 1)
                
                Toggle(isOn: $showInfoView) {
                    Image(systemName: "list.bullet")
                }
                .onChange(of: showInfoView) { newValue in
                    guard newValue else { return }
                    showLabelList = false
                }
                .help("Show Info View")
                .disabled(leftSideBarSelectedItem.count != 1)
                
            }
            
        }
    }
    
}
