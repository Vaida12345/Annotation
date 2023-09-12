//
//  DetailView.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI


struct DetailView: View {
    
    // core
    @EnvironmentObject private var document: AnnotationDocument
    
    // layout
    @State private var showLabelSheet = false
    
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                AnnotationView(size: reader.size)
                
                HStack {
                    VStack {
                        Menu {
                            ForEach(document.labels.values.sorted()) { label in
                                Button {
                                    document.selectedLabel = label
                                } label: {
                                    Text(label.title)
                                        .foregroundStyle(label.color)
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
                        .foregroundColor(.green)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.ultraThinMaterial))
                        .frame(width: 100, height: 20)
                        .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showLabelSheet) {
            NewLabelView(undoManager: undoManager) {
                document.selectedLabel = $0
            }
        }
    }
}
