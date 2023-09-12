//
//  NewLabelView.swift
//  Annotation
//
//  Created by Vaida on 9/12/23.
//

import Foundation
import SwiftUI


struct NewLabelView: View {
    
    // for some reason, has to pass like this
    let undoManager: UndoManager?
    
    let onDismiss: (_ label: AnnotationDocument.Label) -> Void
    
    @State var newLabel = AnnotationDocument.Label(title: "", color: .green)
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var document: AnnotationDocument
    
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Create a new label")
                .font(.title2)
                .bold()
            
            __ChangeLabelNameView(label: $newLabel) {
                document.labels[newLabel.title] = newLabel
                onDismiss(newLabel)
                
                dismiss()
            }
        }
        .padding(.all)
        .frame(width: 500)
    }
}


//#if DEBUG
//#Preview {
//    NewLabelView(undoManager: nil, onDismiss: { _ in })
//        .environmentObject(AnnotationDocument.preview)
//}
//#endif
