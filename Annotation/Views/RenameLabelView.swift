//
//  RenameLabelView.swift
//  Annotation
//
//  Created by Vaida on 2/1/23.
//


import SwiftUI


struct RenameLabelView: View {
    
    let oldLabel: AnnotationDocument.Label
    // for some reason, has to pass like this
    let undoManager: UndoManager?
    @State var newLabel = AnnotationDocument.Label(title: "", color: .green)
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var document: AnnotationDocument
    
    var body: some View {
        ChangeLabelNameView(label: $newLabel) {
            applyAndDismiss()
        }
        .padding()
        .onAppear {
            newLabel = oldLabel
        }
    }
    
    func applyAndDismiss() {
        document.rename(label: oldLabel.title, with: newLabel.title, undoManager: undoManager)
        document.replaceColor(label: newLabel.title, with: newLabel.color, undoManager: undoManager)
        
        dismiss()
    }
    
}
