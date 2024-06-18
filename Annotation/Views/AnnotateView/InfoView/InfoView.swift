//
//  InfoView.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import Stratum
import ViewCollection

struct InfoView: View {
    
    // core
    @Binding var annotation: Annotation
    
    var body: some View {
//        List($annotation.annotations) { item in
//            InfoViewItem(item: item, annotation: $annotation)
//            Divider()
//        }
        
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.fixed(60)), GridItem(.flexible())]) {
                ForEach($annotation.annotations) { item in
                    InfoViewItem(item: item, annotation: $annotation)
                }
            }
            .padding(.all)
        }
        .background(.background)
    }
}

#Preview {
    withStateObserved(initial: AnnotationDocument.preview.annotations.first!) { state in
        InfoView(annotation: state)
            .frame(width: 400)
            .environmentObject(AnnotationDocument.preview)
    }
}

