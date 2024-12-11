//
//  SelectLabelMenu.swift
//  Annotation
//
//  Created by Vaida on 9/12/23.
//

import Foundation
import SwiftUI


struct SelectLabelMenu: View {
    
    @State private var showLabelSheet = false
    
    @EnvironmentObject private var document: AnnotationDocument
    
    @Environment(\.undoManager) private var undoManager
    
    @AppStorage("AnnotationApp.groupLabelMenu") private var groupLabelMenu = false
    
    
    var body: some View {
        Menu {
            if groupLabelMenu {
                SelectLabelGroupedMenu()
            } else {
                ForEach(document.labels.values.sorted()) { label in
                    Button {
                        document.selectedLabel = label
                    } label: {
                        Text(label.title)
                            .foregroundStyle(label.color)
                    }
                }
            }
            
            Divider()
            
            Button("New...") {
                showLabelSheet = true
            }
        } label: {
            Text(document.selectedLabel.title)
                .foregroundStyle(document.selectedLabel.color)
        }
        .sheet(isPresented: $showLabelSheet) {
            NewLabelView(undoManager: undoManager) {
                document.selectedLabel = $0
            }
        }
    }
}


#Preview {
    SelectLabelMenu()
        .environmentObject(AnnotationDocument.preview)
}
