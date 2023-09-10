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
    @State var newLabel = AnnotationDocument.Label(title: "", color: .green)
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        HStack {
            InfoViewImage(annotation: annotation, coordinate: item.coordinate)
                .opacity(item.hidden ? 0.5 : 1.0)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                if !onEdit {
                    Text(item.label)
                        .font(.title3)
                        .foregroundStyle(item.hidden ? .secondary : document.labels.first(where: { $0.title == item.label })?.color ?? .primary)
                } else {
                    Menu {
                        ForEach(Array(document.labels), id: \.self) { label in
                            Button(label.title) {
                                undoManager?.setActionName("Change label to \"\(label)\"")
                                document.apply(undoManager: undoManager) {
                                    item.label = label.title
                                }
                            }
                            .foregroundStyle(label.color)
                        }
                        
                        Divider()
                        
                        Button("New...") {
                            showLabelSheet = true
                        }
                    } label: {
                        Text(item.label)
                    }
                    
                }
                
                Spacer()
                
                HStack {
                    Button {
                        withAnimation {
                            item.hidden.toggle()
                        }
                    } label: {
                        Image(systemName: item.hidden ? "eye.slash.fill" : "eye.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    
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
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showLabelSheet) {
            ChangeLabelNameView(label: $newLabel) {
                undoManager?.setActionName("Rename to \"\(newLabel)\"")
                document.rename(label: item.label, with: newLabel.title, undoManager: undoManager)
            }
            .onAppear {
                newLabel = .init(title: item.label, color: document.labels.first(where: { $0.title == item.label })?.color ?? .primary)
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
