//
//  ChangeLabelNameView.swift
//  Annotation
//
//  Created by Vaida on 9/10/23.
//

import Foundation
import SwiftUI

struct __ChangeLabelNameView: View {
    
    @Binding var label: AnnotationDocument.Label
    
    @EnvironmentObject var document: AnnotationDocument
    
    let dismiss: () -> Void
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Name")
                
                TextField("Name for label", text: $label.title)
                    .onSubmit {
                        dismiss()
                    }
                    .padding(.bottom)
                
                ColorPicker("Color", selection: $label.color)
            }
            .padding(.vertical, 5)
            
            HStack {
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        
    }
    
}
