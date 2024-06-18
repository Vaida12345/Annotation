//
//  LabelListItems.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import Stratum


struct LabelListItems: View {
    
    @EnvironmentObject var document: AnnotationDocument
    @State var label: AnnotationDocument.Label
    @Binding var showLabelList: Bool
    
    @State private var labelsDictionaryValue: Array<Array<Annotation>.LabelDictionaryValue> = []
    
    @State private var innerView: [InnerViewElement] = []
    @State private var isCompleted = false
    
    var body: some View {
        Group {
            if !innerView.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(innerView, id: \.item.annotationsID) { item in
                            LabelListItem(showLabelList: $showLabelList, item: item)
                                .frame(width: 200, height: 200)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                if !isCompleted {
                    HStack {
                        Text("Loading preview")
                        
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding()
                    }
                } else {
                    Text("Empty")
                        .foregroundStyle(.gray)
                        .fontDesign(.rounded)
                        .fontWeight(.heavy)
                }
            }
        }
        .frame(height: LabelListItems.height)
    }
    
    func updateInnerViews(labelsDictionaryValue: Array<Array<Annotation>.LabelDictionaryValue>) async {
        let annotations = document.annotations
        nonisolated(unsafe)
        let _innerView = try! await labelsDictionaryValue.stream.compactMap { (item) -> InnerViewElement? in
            guard let annotation = annotations.first(where: { $0.id == item.annotationID }) else { return nil }
            guard let annotations = annotation.annotations.first(where: { $0.id == item.annotationsID }) else { return nil }
            
            let size = await annotations.coordinate.size.aspectRatio(extend: .height, to: LabelListItems.height)
            guard let croppedImage = trimImage(from: annotation.image, at: annotations.coordinate) else { return nil }
            guard let container = trimImage(from: annotation.image, at: annotations.coordinate.squareContainer()) else { return nil }
            
            return InnerViewElement(item: item, croppedImage: croppedImage, container: container, size: size)
        }.sequence
        
        self.labelsDictionaryValue = labelsDictionaryValue
        self.innerView = _innerView
        self.isCompleted = true
    }
    
    static let height: CGFloat = 200
    
    struct InnerViewElement {
        
        let item: Array<Annotation>.LabelDictionaryValue
        
        let croppedImage: NativeImage
        
        let container: NativeImage
        
        let size: CGSize
        
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
