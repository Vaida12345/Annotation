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
    @Environment(AnnotationDocument.self) private var document
    
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Create a new label")
                .font(.title2)
                .bold()
            
            __ChangeLabelNameView(label: newLabel) { _, newLabel in
                guard let created = try? document.addLabel(title: newLabel.title, color: newLabel.color, undoManager: undoManager) else { return }
                undoManager?.setActionName("Create label")
                onDismiss(created)
                
                dismiss()
            }
        }
        .padding(.all)
        .frame(width: 500)
    }
}


#if DEBUG
#Preview {
    NewLabelView(undoManager: nil, onDismiss: { _ in })
        .environment(AnnotationDocument.preview)
}
#endif
