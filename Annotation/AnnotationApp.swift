//
//  AnnotationApp.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import CoreML
import UniformTypeIdentifiers
import Stratum

@main
struct AnnotationApp: App {
    
    @FocusedValue(\.document) var document
    
    @AppStorage("AnnotationApp.groupLabelMenu") private var groupLabelMenu = false
    
    var body: some Scene {
        DocumentGroup(newDocument: { AnnotationDocument() }) { file in
            AppView()
                .focusedSceneValue(\.document, file.document)
        }
        .commands {
            ImportExportCommand()
            
            AnnotateCommand()
            
            SidebarCommands()
            
            CommandGroup(after: .sidebar) {
                Divider()
                
                Toggle("Group Label Menu", isOn: $groupLabelMenu)
            }
        }
    }
}
