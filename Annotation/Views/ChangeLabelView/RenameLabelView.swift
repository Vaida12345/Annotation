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
        VStack(alignment: .leading) {
            Text("Rename \(oldLabel.title)")
                .font(.title2)
                .bold()
            
            __ChangeLabelNameView(label: $newLabel) {
                undoManager?.beginUndoGrouping()
                document.rename(label: oldLabel.title, with: newLabel.title, undoManager: undoManager)
                document.replaceColor(label: newLabel.title, with: newLabel.color, undoManager: undoManager)
                undoManager?.endUndoGrouping()
                undoManager?.setActionName("Edit label")
                
                dismiss()
            }
        }
        .padding()
        .onAppear {
            newLabel = oldLabel
        }
    }
}


//#if DEBUG
//#Preview {
//    RenameLabelView(oldLabel: .init(title: "1", color: .white), undoManager: nil)
//        .environmentObject(AnnotationDocument.preview)
//}
//#endif
