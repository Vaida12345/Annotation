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
    
//    @State private var cursorPosition = CGPoint.zero
//    @State private var showCursor = false
    
//    let sideBarWidth: Double
    
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                AnnotationView(label: currentLabel, size: reader.size)
                
                HStack {
                    VStack {
                        Menu {
                            ForEach(Array(document.labels), id: \.self) { label in
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
                
//                if showCursor {
//                    HStack {
//                        Rectangle()
//                            .fill(.yellow)
//                            .frame(width: 0.5, height: reader.size.height)
//                        
//                        Spacer()
//                    }
//                    .offset(x: cursorPosition.x - sideBarWidth)
//                }
            }
//            .onHover { isHovering in
//                showCursor = isHovering
//            }
//            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didUpdateNotification)) { _ in
//                cursorPosition = NSEvent.mouseLocation
//            }
        }
        .sheet(isPresented: $showLabelSheet) {
            ChangeLabelNameView(label: $currentLabel) {
                showLabelSheet = false
                document.labels.insert(currentLabel)
            }
            .padding()
        }
    }
}
