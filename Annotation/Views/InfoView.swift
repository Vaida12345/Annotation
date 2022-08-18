//
//  InfoView.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI

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
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        HStack {
            InfoViewImage(annotation: annotation, coordinate: item.coordinates)
            HStack {
                VStack {
                    if !onEdit {
                        Text(item.label)
                            .font(.title3)
                    } else {
                        Menu {
                            ForEach(document.annotations.labels, id: \.self) { label in
                                Button(label) {
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
                }
                
                Spacer()
                
                HStack(alignment: .center) {
                    Image(systemName: "pencil")
                        .onTapGesture {
                            onEdit.toggle()
                        }
                    
                    Image(systemName: "trash")
                        .onTapGesture {
                            withAnimation {
                                document.apply(undoManager: undoManager) {
                                    annotation.annotations.removeAll(where: { $0 == item })
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showLabelSheet) {
            VStack {
                HStack {
                    Text("Name for label: ")
                    
                    Spacer()
                }
                TextField("Name for label", text: $newLabel)
                    .onSubmit {
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
    
    @State var image: NSImage? = nil
    
    var body: some View {
        if let image = image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 75, height: 75)
                .cornerRadius(5)
        } else {
            GroupBox{
                VStack {
                    HStack {
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(width: 75, height: 75)
            .onAppear {
                DispatchQueue(label: "trim image").async {
                    image = trimImage(from: annotation.image, at: coordinate)
                }
            }
        }
    }
}
