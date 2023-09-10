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
    @EnvironmentObject var document: AnnotationDocument
    
    // layout
    @State var showLabelSheet = false
    @State var currentLabel = Annotation.Label(title: "New Label", color: .gray)
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                AnnotationView(label: $currentLabel, size: reader.size)
                
                HStack {
                    VStack {
                        Menu {
                            ForEach(document.annotations.labels, id: \.self) { label in
                                Button {
                                    currentLabel = label
                                } label: {
                                    Text(label.title)
                                        .foregroundStyle(label.color)
                                }
                            }
                            
                            Divider()
                            
                            Button("New...") {
                                currentLabel = .init(title: "New Label", color: .green)
                                showLabelSheet = true
                            }
                        } label: {
                            Text(currentLabel.title)
                                .foregroundStyle(currentLabel.color)
                        }
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
            VStack {
                ChangeLabelNameView(label: $currentLabel) {
                    showLabelSheet = false
                }
                
                HStack {
                    Spacer()
                    
                    Button("Done") {
                        showLabelSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(width: 400)
            }
            .padding()
        }
    }
}
