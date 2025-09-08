//
//  ImportExportCommand.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI


struct ImportExportCommand: Commands {
    
    @FocusedValue(\.document) private var document: AnnotationDocument?
    
    
    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            Section {
                Button("Import") {
                    document?.isShowingImportDialog = true
                }
                .keyboardShortcut("i")
                
                Button("Export...") {
                    document?.isShowingExportDialog = true
                }
                .keyboardShortcut("e")
            }
        }
    }
    
}

extension FocusedValues {
    struct DocumentFocusedValues: FocusedValueKey {
        typealias Value = AnnotationDocument
    }
    
    var document: AnnotationDocument? {
        get {
            self[DocumentFocusedValues.self]
        }
        set {
            self[DocumentFocusedValues.self] = newValue
        }
    }
}
