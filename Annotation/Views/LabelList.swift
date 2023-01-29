//
//  LabelList.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import Support

struct LabelList: View {
    
    // core
    @EnvironmentObject var document: AnnotationDocument
    
    @Binding var leftSideBarSelectedItem: Set<Annotation.ID>
    
    @State var showLabelSheet = false
    @State var oldName: String = ""
    @State var newLabel: String = ""
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        List(document.annotations.labels, id: \.self) { label in
            VStack {
                HStack {
                    Text(label)
                    Image(systemName: "pencil")
                        .onTapGesture {
                            oldName = label
                            showLabelSheet = true
                        }
                    Spacer()
                    Image(systemName: "trash")
                        .onTapGesture {
                            document.apply(undoManager: undoManager) {
                                for index in 0..<document.annotations.count {
                                    document.annotations[index].annotations.removeAll(where: { $0.label == label })
                                }
                            }
                        }
                }
                
                LabelListItems(leftSideBarSelectedItem: $leftSideBarSelectedItem, label: label)
                
                Divider()
            }
        }
        .sheet(isPresented: $showLabelSheet) {
            VStack {
                HStack {
                    Text("Name for label: ")
                    
                    Spacer()
                }
                TextField(oldName, text: $newLabel)
                    .onSubmit {
                        document.apply(undoManager: undoManager) {
                            for i in 0..<document.annotations.count {
                                for ii in 0..<document.annotations[i].annotations.count {
                                    if document.annotations[i].annotations[ii].label == oldName {
                                        document.annotations[i].annotations[ii].label = newLabel
                                    }
                                }
                            }
                        }
                        
                        showLabelSheet = false
                    }
                    .onAppear {
                        newLabel = oldName
                    }
                HStack {
                    Spacer()
                    
                    Button("Done") {
                        document.apply(undoManager: undoManager) {
                            for i in 0..<document.annotations.count {
                                for ii in 0..<document.annotations[i].annotations.count {
                                    if document.annotations[i].annotations[ii].label == oldName {
                                        document.annotations[i].annotations[ii].label = newLabel
                                    }
                                }
                            }
                        }
                        
                        showLabelSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(width: 400)
            }
            .padding()
        }
    }
}

struct LabelListItems: View {
    
    @EnvironmentObject var document: AnnotationDocument
    @Binding var leftSideBarSelectedItem: Set<Annotation.ID>
    @State var label: String
    
    var body: some View {
        
        if let labelsDictionary = document.annotations.labelDictionary[label] {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(labelsDictionary, id: \.1.id) { item in
                        LabelListItem(item: item)
                            .onTapGesture(count: 2) {
                                guard let index = document.annotations.firstIndex(where: { $0.image == item.0 }) else { return }
                                leftSideBarSelectedItem = [document.annotations[index].id]
                            }
                    }
                }
            }
        }
        
    }
}

struct LabelListItem: View {
    
    @State var item: (NSImage, Annotation.Annotations.Coordinate)
    
    var body: some View {
        AsyncView {
            trimImage(from: item.0, at: item.1) ?? NSImage()
        } content: { image in
            Image(nsImage: image)
                .resizable()
                .cornerRadius(5)
                .aspectRatio(contentMode: .fit)
                .frame(height: 50)
        }
        .frame(height: 50)
    }
}
