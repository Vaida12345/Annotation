//
//  LabelListRow.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI


struct LabelListRow: View {
    
    @EnvironmentObject var document: AnnotationDocument
    
    let label: AnnotationDocument.Label
    
    @Binding var showLabelList: Bool
    
    @State private var onHover = false
    @State private var showEdit = false
    
    @Environment(\.undoManager) private var undoManager
    
    
    var body: some View {
        VStack {
            HStack {
                Text(label.title)
                    .fontDesign(.rounded)
                    .font(.title)
                    .foregroundStyle(label.color)
                
                Spacer()
                
                if onHover {
                    HStack {
                        Image(systemName: "pencil")
                            .onTapGesture {
                                withAnimation {
                                    showEdit = true
                                }
                            }
                        
                        Image(systemName: "trash")
                            .onTapGesture {
                                document.remove(undoManager: undoManager, label: label)
                            }
                    }
                    .padding(.trailing, 23)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.leading, 30)
            
            LabelListItems(label: label, showLabelList: $showLabelList)
                .scrollIndicators(.never)
            
            Divider()
        }
        .id(label)
        .onHover { newValue in
            withAnimation {
                onHover = newValue
            }
        }
        .sheet(isPresented: $showEdit) {
            RenameLabelView(label: label, undoManager: undoManager)
                .id(label)
        }
    }
}
