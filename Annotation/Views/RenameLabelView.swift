//
//  RenameLabelView.swift
//  Annotation
//
//  Created by Vaida on 2/1/23.
//


import SwiftUI


struct RenameLabelView: View {
    
    let oldLabel: AnnotationDocument.Label
    @State var newLabel = AnnotationDocument.Label(title: "", color: .green)
    
    @Environment(\.undoManager) var undoManager
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
