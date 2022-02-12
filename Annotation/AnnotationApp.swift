//
//  AnnotationApp.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI

@main
struct AnnotationApp: App {
    
    var body: some Scene {
        DocumentGroup(newDocument: AnnotationDocument()) { file in
            DocumentView(document: file.$document)
        }
    }
}


