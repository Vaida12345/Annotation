//
//  InfoView.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import Support

struct InfoView: View {
    
    // core
    @Binding var annotation: Annotation
    
    var body: some View {
        List($annotation.annotations) { item in
            InfoViewItem(item: item, annotation: $annotation)
            Divider()
        }
    }
}

struct InfoViewItem: View {
    
    @Binding var item: Annotation.Annotations
    @Binding var annotation: Annotation
    @EnvironmentObject var document: AnnotationDocument
    
    @State var onEdit = false
    @State var showLabelSheet = false
    @State var newLabel = ""
    
    @State private var isOnHover = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        HStack {
            InfoViewImage(annotation: annotation, coordinate: item.coordinates)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                if !onEdit {
                    Text(item.label)
                        .font(.title3)
                } else {
                    Menu {
                        ForEach(document.annotations.labels, id: \.self) { label in
                            Button(label) {
                                undoManager?.setActionName("Rename to \"\(label)\"")
                                document.apply(undoManager: undoManager) {
                                    item.label = label
                                }
                            }
                        }
                        
                        Button("New...") {
                            showLabelSheet = true
                        }
                    } label: {
                        Text(item.label)
                    }
                    
                }
                
                Spacer()
                
                if isOnHover {
                    HStack {
                        Image(systemName: onEdit ? "checkmark" : "pencil")
                            .onTapGesture {
                                onEdit.toggle()
                            }
                        
                        Image(systemName: "trash")
                            .onTapGesture {
                                withAnimation {
                                    undoManager?.setActionName("Remove item")
                                    document.apply(undoManager: undoManager) {
                                        annotation.annotations.removeAll(where: { $0 == item })
                                    }
                                }
                            }
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .onHover { hover in
            self.isOnHover = hover
        }
        .sheet(isPresented: $showLabelSheet) {
            VStack {
                HStack {
                    Text("Name for label: ")
                    
                    Spacer()
                }
                TextField("Name for label", text: $newLabel)
                    .onSubmit {
                        undoManager?.setActionName("Rename to \"\(newLabel)\"")
                        document.apply(undoManager: undoManager) {
                            item.label = newLabel
                            showLabelSheet = false
                        }
                    }
                    .onAppear {
                        newLabel = item.label
                    }
                HStack {
                    Spacer()
                    
                    Button("Done") {
                        undoManager?.setActionName("Rename to \"\(newLabel)\"")
                        document.apply(undoManager: undoManager) {
                            item.label = newLabel
                            showLabelSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(width: 400)
            }
            .padding()
        }
    }
}

struct InfoViewImage: View {
    
    @State var annotation: Annotation
    @State var coordinate: Annotation.Annotations.Coordinate
    
    var body: some View {
        AsyncView {
            trimImage(from: annotation.image, at: coordinate) ?? NSImage()
        } content: { image in
            Image(nsImage: image)
                .resizable()
                .cornerRadius(5)
                .aspectRatio(contentMode: .fit)
                .frame(height: 75)
        }
        .frame(height: 75)
    }
}
