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
    @State var label = "label"
    @EnvironmentObject var document: AnnotationDocument
    
    // layout
    @Binding var leftSideBarSelectedItem: Set<Annotation.ID>
    @State var showInfoView = false
    @State var showLabelList = false
    @State var showPopover = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        NavigationView {
            SideBar(selection: $leftSideBarSelectedItem)
            
            ZStack {
                if !document.annotations.isEmpty {
                    DetailView(leftSideBarSelectedItem: $leftSideBarSelectedItem)
                } else {
                    VStack {
                        Image(systemName: "square.and.arrow.down.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(.all)
                            .frame(width: 100, height: 100, alignment: .center)
                        Text("Drag files or folder.")
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .padding(.all)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                DispatchQueue(label: "adder").async {
                    Task {
                        for i in providers {
                            // the priority doesn't work, as load item is recommended to run on main thread.
                            guard let result = try? await i.loadItem(forTypeIdentifier: "public.file-url", options: nil) else { return }
                            guard let urlData = result as? Data else { return }
                            guard let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                            await document.addItems(from: [url], undoManager: undoManager)
                        }
                    }
                }
                
                return true
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
                
                Toggle(isOn: $showLabelList.animation()) {
                    Image(systemName: "tag")
                }
                .onChange(of: showLabelList) { newValue in
                    withAnimation {
                        guard newValue else { return }
                        showInfoView = false
                    }
                }
                .help("Show Label List")
                .disabled(leftSideBarSelectedItem.count != 1)
                
                Toggle(isOn: $showInfoView.animation()) {
                    Image(systemName: "list.bullet")
                }
                .onChange(of: showInfoView) { newValue in
                    withAnimation {
                        guard newValue else { return }
                        showLabelList = false
                    }
                }
                .help("Show Info View")
                .disabled(leftSideBarSelectedItem.count != 1)
                
            }
            
        }
    }
    
}
