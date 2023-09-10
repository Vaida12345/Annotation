//
//  ChangeLabelNameView.swift
//  Annotation
//
//  Created by Vaida on 9/10/23.
//

import Foundation
import SwiftUI

struct ChangeLabelNameView: View {
    
    @Binding var label: Annotation.Label
    
    let dismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Name for label: ")
            
            TextField("Name for label", text: $label.title)
                .onSubmit {
                    dismiss()
                }
            
            ColorPicker("Color of label: ", selection: $label.color)
        }
        .padding(.vertical, 5)
    }
    
}
