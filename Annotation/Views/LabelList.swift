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
    @Binding var showLabelList: Bool
    
    @State var showLabelSheet = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        List(document.annotations.labels, id: \.self) { label in
            VStack {
                HStack {
                    Text(label)
                        .font(.title)
                    Image(systemName: "pencil")
                        .onTapGesture {
                            showLabelSheet = true
                        }
                        .sheet(isPresented: $showLabelSheet) {
                            RenameLabelView(oldName: label)
                        }
                    Spacer()
                    Image(systemName: "trash")
                        .onTapGesture {
                            document.remove(undoManager: undoManager, label: label)
                        }
                }
                
                LabelListItems(label: label, showLabelList: $showLabelList)
                
                Divider()
            }
        }
    }
}

struct LabelListItems: View {
    
    @EnvironmentObject var document: AnnotationDocument
    @State var label: String
    @Binding var showLabelList: Bool
    
    var body: some View {
        
        if let labelsDictionary = document.annotations.labelDictionary[label] {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(labelsDictionary, id: \.annotationsID) { item in
                        LabelListItem(showLabelList: $showLabelList, item: item)
                    }
                }
            }
        }
        
    }
}

struct LabelListItem: View {
    
    // core
    @EnvironmentObject var document: AnnotationDocument
    @Binding var showLabelList: Bool
    
    let item: Array<Annotation>.LabelDictionaryValue
    
    @Environment(\.undoManager) var undoManager
    @Environment(\.dismiss) var dismiss
    
    var contextMenu: some View {
        Menu {
            Button("Show Image") {
                withAnimation {
                    document.leftSideBarSelectedItem = [item.annotationID]
                    showLabelList = false
                }
            }
            
            Divider()
            
            Button("Remove") {
                withAnimation {
                    document.removeAnnotations(undoManager: undoManager, annotationID: item.annotationID, annotationsID: item.annotationsID)
                }
            }
        } label: {
            
        }
    }
    
    var body: some View {
        AsyncView { () -> NSImage? in
            guard let annotation = await document.annotations.first(where: { $0.id == item.annotationID }) else { return nil }
            guard let annotations = annotation.annotations.first(where: { $0.id == item.annotationsID }) else { return nil }
            
            return trimImage(from: annotation.image, at: annotations.coordinates) ?? NSImage()
        } content: { image in
            Image(nsImage: image ?? NSImage())
                .resizable()
                .cornerRadius(5)
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
                .contextMenu {
                    contextMenu
                }
                .overlay(alignment: .topTrailing) {
                    contextMenu
                        .menuStyle(.borderlessButton)
                        .frame(width: 10)
                        .padding(2)
                        .foregroundColor(.blue)
                }
        }
        .frame(height: 200)
    }
}
