//
//  AnnotateCommand.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI


struct AnnotateCommand: Commands {
    
    @FocusedValue(\.document) private var document: AnnotationDocument?
    
    var body: some Commands {
        CommandMenu("Annotate") {
            Button {
                document?.isShowingAutoAnnotate.toggle()
            } label: {
                Label("Based on model...", systemImage: "shippingbox")
            }
            
            Button {
                document?.isShowingAutoDetect.toggle()
            } label: {
                Label("Auto detect...", systemImage: "lasso.badge.sparkles")
            }
        }
    }
    
}
