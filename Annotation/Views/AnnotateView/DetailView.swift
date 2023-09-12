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
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                AnnotationView(size: reader.size)
                
                HStack {
                    VStack {
                        SelectLabelMenu()
                            .background(RoundedRectangle(cornerRadius: 5).fill(.ultraThinMaterial))
                            .frame(width: 100, height: 20)
                            .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
        }
        
    }
}
