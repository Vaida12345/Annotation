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
    @State private var currentLabel = AnnotationDocument.Label(title: "New Label", color: .gray)
    
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                AnnotationView(label: currentLabel, size: reader.size)
                
                HStack {
                    VStack {
                        Menu {
                            ForEach(Array(document.labels).sorted(), id: \.self) { label in
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
            ChangeLabelNameView(label: $currentLabel) {
                showLabelSheet = false
                print(currentLabel)
                document.labels.insert(currentLabel)
            }
            .padding()
        }
    }
}
