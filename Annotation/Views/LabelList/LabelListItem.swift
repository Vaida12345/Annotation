//
//  LabelListItem.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import ViewCollection


struct LabelListItem: View {
    
    // core
    @EnvironmentObject var document: AnnotationDocument
    @Binding var showLabelList: Bool
    
    let item: LabelListItems.InnerViewElement
    
    @Environment(\.undoManager) var undoManager
    @Environment(\.dismiss) var dismiss
    
    @ViewBuilder
    var contextMenuContents: some View {
        Button("Show Image") {
            withAnimation {
                document.selectedItems = [item.item.annotationID]
                document.scrollProxy?.scrollTo(item.item.annotationID)
                showLabelList = false
            }
        }
        
        Divider()
        
        Button("Remove") {
            withAnimation {
                document.removeAnnotations(undoManager: undoManager, annotationID: item.item.annotationID, annotationsID: item.item.annotationsID)
            }
        }
    }
    
    var body: some View {
        ZStack {
            AsyncDrawnImage(cgImage: item.container, frame: .square(200))
                .cornerRadius(10)
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(width: 200, height: 200)
                .cornerRadius(10)
            
            AsyncDrawnImage(cgImage: item.croppedImage, frame: .square(200))
        }
        .contextMenu {
            contextMenuContents
        }
    }
}


#Preview {
    withStateObserved(initial: false) { state in
        LabelListItems(label: AnnotationDocument.preview.labels.first!.value,
                       showLabelList: state)
        .frame(width: 300, height: 300)
        .padding(.all)
        .environmentObject(AnnotationDocument.preview)
    }
}
