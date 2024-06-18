//
//  AutoAnnotateView.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import CoreML
import Vision
import Stratum

struct AutoAnnotateView: View {
    
    @State private var confidence: Double = 0.8
    @State private var model: MLModel?
    @State private var unannotatedImageOnly = true
    
    @EnvironmentObject var document: AnnotationDocument
    @Environment(\.dismiss) var dismiss
    
    let undoManager: UndoManager?
    
    var body: some View {
        
        HStack {
            DropHandlerView(prompt: "Drop a CoreML model here")
                .onDrop { sources in
                    guard let firstItem = sources.first else { return }
                    let model = try MLModel(contentsOf: MLModel.compileModel(at: firstItem.url))
                    
                    Task {
                        self.model = model
                        dismiss()
                        await applyML()
                    }
                }
                .background(.regularMaterial)
                .frame(width: 400, height: 300)
            
            VStack(alignment: .leading) {
                
                Text("Confidence")
                
                Slider(value: $confidence, in: 0...1)
                
                Toggle("Unannotated Images Only", isOn: $unannotatedImageOnly)
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding()
            .frame(width: 210, height: 300)
        }
    }
    
    func applyML() async {
        guard let model = model else { return }
        let oldItems = document.annotations
        self.document.selectedItems = []
        
        let _document = document
        let staticConfidence = confidence
        
        let _unannotatedImagesOnly = unannotatedImageOnly
        
        nonisolated(unsafe)
        let images = _document.annotations.map(\.image).compactMap(\.cgImage)
        
        for i in 0..<_document.annotations.count {
            if _unannotatedImagesOnly && !_document.annotations[i].annotations.isEmpty {
                continue
            }
            
            guard let result = await applyObjectDetectionML(to: images[i], model: model) else {
                Task { @MainActor in document.selectedItems = [document.annotations[i].id] }
                continue
            }
            let annotations = result.filter({ $0.confidence >= Float(staticConfidence) }).compactMap { item -> Annotation.Annotations? in
                guard let label = item.labels.first?.identifier else { return nil }
                let coordinate = Annotation.Annotations.Coordinate(from: item, in: images[i])
                return Annotation.Annotations.init(label: label, coordinates: coordinate)
            }
            
            Task { @MainActor in
                document.annotations[i].annotations.append(contentsOf: annotations)
                
                document.selectedItems = [document.annotations[i].id]
                document.scrollProxy?.scrollTo(document.annotations[i].id)
            }
        }
        
        
        // synchronize labels
        let _labels = document.annotations.__labels
        let difference = Set(_labels).subtracting(document.labels.keys)
        document.objectWillChange.send()
        for i in difference {
            document.labels[i] = .init(title: i, color: .green)
        }
        
        // undo / redo
        undoManager?.setActionName("Auto Annotate")
        undoManager?.registerUndo(withTarget: document) { document in
            document.replaceItems(with: oldItems, undoManager: undoManager)
            
            for i in difference {
                document.labels[i] = nil
            }
        }
        
    }
}


//#if DEBUG
//#Preview {
//    AutoAnnotateView(undoManager: nil)
//        .environmentObject(AnnotationDocument.preview)
//}
//#endif


/// Returns the ML result by applying an Object Detection ML model to an image.
///
/// **Example**
///
///     applyML(to: NSImage(), model: Normal_Image_Classifier_2().model)
///
/// - Important: The class would be returned only if the confidence is greater than the threshold.
///
/// - Note: By default, the threshold, ie. confidence, was set to 0.8.
///
/// - Attention: The return value is `nil` if the size of `image` is `zero`, the `MLModel` is invalid, or no item reaches the threshold.
///
/// - Parameters:
///     - confidence: The threshold.
///     - model: The Object Detection ML Classifier model.
///     - image: The image on which performs the ML.
///
/// - Returns: The observations in the image; `nil` otherwise.
func applyObjectDetectionML(to image: CGImage, model: MLModel) async -> [VNRecognizedObjectObservation]? {
    let orientation = CGImagePropertyOrientation.up
    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
    
    let model = try! VNCoreMLModel(for: model)
    let request = VNCoreMLRequest(model: model)
    try! handler.perform([request])
    
    guard let results = request.results else { return nil }
    let observations = results as! [VNRecognizedObjectObservation]
    guard !observations.isEmpty else { return nil }
    
    return observations
}
