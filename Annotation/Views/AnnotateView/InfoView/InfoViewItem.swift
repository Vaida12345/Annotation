//
//  Untitled.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import ViewCollection


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

#Preview {
    withStateObserved(initial: AnnotationDocument.preview.annotations[0]) { annotation in
        withStateObserved(initial: annotation.annotations[0].wrappedValue) { state in
            LazyVGrid(columns: [GridItem(.fixed(60)), GridItem(.flexible())]) {
                GridRow {
                    InfoViewItem(item: state, annotation: annotation)
                }
            }
        }
    }
    .environmentObject(AnnotationDocument.preview)
    .frame(width: 400)
    .padding(.all)
}
