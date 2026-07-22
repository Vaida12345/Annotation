//
//  LabelList.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import ViewCollection


struct LabelList: View {
    
    // core
    @Environment(AnnotationDocument.self) private var document
    @Binding var showLabelList: Bool
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack {
                ForEach(document.labels.values.sorted()) { label in
                    LabelListRow(label: label, showLabelList: $showLabelList)
                }
            }
            .padding(.top)
        }
    }
}


#Preview {
    @Previewable @State var showLabelList = false

    LabelList(showLabelList: $showLabelList)
        .environment(AnnotationDocument.preview)
}
