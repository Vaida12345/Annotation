//
//  RenameLabelView.swift
//  Annotation
//
//  Created by Vaida on 2/1/23.
//


import SwiftUI


struct RenameLabelView: View {
    
    let oldLabel: Annotation.Label
    @State var newLabel = Annotation.Label(title: "", color: .green)
    
    @Environment(\.undoManager) var undoManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var document: AnnotationDocument
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Rename label of \(oldLabel.title)")
                .font(.title2)
                .bold()
            
            ChangeLabelNameView(label: $newLabel) {
                applyAndDismiss()
            }
            
            HStack {
                Spacer()
                
                Button("Done") {
                    applyAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear {
            newLabel = oldLabel
        }
        .frame(width: 400)
    }
    
    func applyAndDismiss() {
        document.rename(label: oldLabel, with: newLabel, undoManager: undoManager)
        
        dismiss()
    }
    
}
