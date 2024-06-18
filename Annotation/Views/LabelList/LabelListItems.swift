//
//  LabelListItems.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import Stratum
import ViewCollection


struct LabelListItems: View {
    
    @EnvironmentObject var document: AnnotationDocument
    @State var label: AnnotationDocument.Label
    @Binding var showLabelList: Bool
    
    @State private var isCompleted = false
    
    struct Capture: Equatable {
        
        let document: AnnotationDocument
        
        static func == (_ lhs: Self, _ rhs: Self) -> Bool {
            lhs.document.labels == rhs.document.labels
        }
        
    }
    
    nonisolated func updates() async throws -> [InnerViewElement] {
        let annotations = await document.annotations
        
        try Task.checkCancellation()
        
        let labelsDictionaryValue = await document.annotations.labelDictionary(of: label.title)
        
        try Task.checkCancellation()
        
        return try! await labelsDictionaryValue.stream.compactMap { (item) -> InnerViewElement? in
            try Task.checkCancellation()
            guard let annotation = annotations.first(where: { $0.id == item.annotationID }) else { return nil }
            guard let annotations = annotation.annotations.first(where: { $0.id == item.annotationsID }) else { return nil }
            
            try Task.checkCancellation()
            guard let croppedImage = await trimImage(from: annotation.image, at: annotations.coordinate) else { return nil }
            try Task.checkCancellation()
            guard let container = await trimImage(from: annotation.image, at: annotations.coordinate.squareContainer()) else { return nil }
            
            try Task.checkCancellation()
            
            return InnerViewElement(item: item, croppedImage: croppedImage, container: container)
        }.sequence
    }
    
    var body: some View {
        AsyncView(generator: updates) { innerView in
            ScrollView(.horizontal) {
                HStack {
                    ForEach(innerView, id: \.item.annotationsID) { item in
                        LabelListItem(showLabelList: $showLabelList, item: item)
                            .frame(width: 200, height: 200)
                    }
                }
                .padding(.horizontal)
            }
        } placeHolder: {
            ContainerView {
                Text("Loading...")
                    .foregroundStyle(.secondary)
                    .fontDesign(.rounded)
                    .font(.title2)
            }
        }
        .frame(height: 200)
    }
    
    struct InnerViewElement {
        
        let item: Array<Annotation>.LabelDictionaryValue
        
        let croppedImage: CGImage
        
        let container: CGImage
        
    }
}


#Preview {
    withStateObserved(initial: false) { state in
        LabelListItems(label: AnnotationDocument.preview.labels.first!.value,
                       showLabelList: state)
        .frame(width: 300, height: 300)
        .environmentObject(AnnotationDocument.preview)
    }
}
