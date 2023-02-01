//
//  RenameLabelView.swift
//  Annotation
//
//  Created by Vaida on 2/1/23.
//


import SwiftUI


struct RenameLabelView: View {
    
    let oldName: String
    @State var newLabel: String = ""
    
    @Environment(\.undoManager) var undoManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var document: AnnotationDocument
    
    var body: some View {
        VStack {
            HStack {
                Text("Name for label: ")
                
                Spacer()
            }
            TextField(oldName, text: $newLabel)
                .onSubmit {
                    applyAndDismiss()
                }
            HStack {
                Spacer()
                
                Button("Done") {
                    applyAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .frame(width: 400)
        }
        .padding()
        .onAppear {
            newLabel = oldName
        }
    }
    
    func applyAndDismiss() {
        document.rename(label: oldName, with: newLabel, undoManager: undoManager)
        
        dismiss()
    }
    
}
