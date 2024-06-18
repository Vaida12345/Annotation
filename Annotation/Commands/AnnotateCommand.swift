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
            Button("Based on model...") {
                document?.isShowingAutoAnnotate.toggle()
            }
            
            Button("Auto detect...") {
                document?.isShowingAutoDetect.toggle()
            }
        }
    }
    
}
