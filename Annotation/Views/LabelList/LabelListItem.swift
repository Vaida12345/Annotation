//
//  LabelListItem.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import Stratum


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
            Image(nsImage: item.container)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .cornerRadius(10)
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(width: 200, height: 200)
                .cornerRadius(10)
            
            Image(nsImage: item.croppedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
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
