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
    @Binding var leftSideBarSelectedItem: Set<Annotation.ID>
    @EnvironmentObject var document: AnnotationDocument
    
    // layout
    @State var showLabelSheet = false
    @State var currentLabel: String = "New Label"
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                AnnotationView(leftSideBarSelectedItem: $leftSideBarSelectedItem, label: $currentLabel, size: reader.size)
                
                HStack {
                    VStack {
                        Menu {
                            ForEach(document.annotations.labels, id: \.self) { label in
                                Button(label) {
                                    currentLabel = label
                                }
                            }
                            Button("New...") {
                                currentLabel = "New Label"
                                showLabelSheet = true
                            }
                        } label: {
                            Text(currentLabel)
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
                HStack {
                    Text("Name for label: ")
                    
                    Spacer()
                }
                TextField("Name for label", text: $currentLabel)
                    .onSubmit {
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
