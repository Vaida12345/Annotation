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
//        List($annotation.annotations) { item in
//            InfoViewItem(item: item, annotation: $annotation)
//            Divider()
//        }
        
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.fixed(60)), GridItem(.flexible())]) {
                ForEach($annotation.annotations) { item in
                    InfoViewItem(item: item, annotation: $annotation)
                }
            }
            .padding(.all)
        }
        .background(.background)
    }
}

struct InfoViewItem: View {
    
    @Binding var item: Annotation.Annotations
    @Binding var annotation: Annotation
    @EnvironmentObject var document: AnnotationDocument
    
    @State var showLabelSheet = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        InfoViewImage(annotation: annotation, coordinate: item.coordinate)
            .opacity(item.hidden ? 0.5 : 1.0)
        
        VStack(alignment: .trailing) {
            Menu {
                ForEach(document.labels.values.sorted()) { label in
                    Button(label.title) {
                        undoManager?.setActionName("Change label to \"\(label.title)\"")
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
                
                Image(systemName: "trash")
                    .onTapGesture {
                        withAnimation {
                            undoManager?.setActionName("Remove annotation")
                            document.apply(undoManager: undoManager) {
                                annotation.annotations.removeAll(where: { $0 == item })
                            }
                        }
                    }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Divider()
        }
        .sheet(isPresented: $showLabelSheet) {
            NewLabelView(undoManager: undoManager) { label in
                undoManager?.setActionName("Change label to \"\(label.title)\"")
                document.apply(undoManager: undoManager) {
                    item.label = label.title
                }
            }
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
