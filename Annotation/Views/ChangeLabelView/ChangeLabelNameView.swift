//
//  ChangeLabelNameView.swift
//  Annotation
//
//  Created by Vaida on 9/10/23.
//

import Foundation
import SwiftUI

import ViewCollection


struct __ChangeLabelNameView: View {
    
    @State var label: AnnotationDocument.Label
    
    let original: AnnotationDocument.Label
    
    @EnvironmentObject var document: AnnotationDocument
    
    let dismiss: (_ original: AnnotationDocument.Label, _ modified: AnnotationDocument.Label) -> Void
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Name")
                
                TextField("Name for label", text: $label.title)
                    .onSubmit {
                        dismiss(original, label)
                    }
                    .padding(.bottom)
            }
            .padding(.vertical, 5)
            
            HStack {
                ColorPaletteView(color: $label.color)
                    .showCustomColorPicker(true)
                    .frame(width: 300, height: 30)
                
                Spacer()
                
                Button("Done") {
                    dismiss(original, label)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    init(label: AnnotationDocument.Label, dismiss: @escaping (_: AnnotationDocument.Label, _: AnnotationDocument.Label) -> Void) {
        self.label = .init(title: label.title, color: label.color)
        self.original = AnnotationDocument.Label(title: label.title, color: label.color)
        self.dismiss = dismiss
    }
    
}


#if DEBUG
#Preview {
    __ChangeLabelNameView(label: AnnotationDocument.Label(title: "hello", color: .blue), dismiss: { _, _ in
        
    })
        .environmentObject(AnnotationDocument.preview)
}
#endif
