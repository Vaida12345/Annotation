//
//  LabelList.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import Stratum

struct LabelList: View {
    
    // core
    @EnvironmentObject var document: AnnotationDocument
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
    withStateObserved(initial: false) { state in
        LabelList(showLabelList: state)
            .environmentObject(AnnotationDocument.preview)
    }
}
