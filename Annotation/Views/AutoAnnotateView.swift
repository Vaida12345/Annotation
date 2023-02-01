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
import Support

struct AutoAnnotateView: View {
    
    @State var confidence: String = "0.8"
    @State var model: MLModel?
    
    @EnvironmentObject var document: AnnotationDocument
    @Environment(\.undoManager) var undoManager
    @Environment(\.dismiss) var dismiss
    
    @State var alertManager = AlertManager()
    
    var body: some View {
        
        VStack {
            DropHandlerView(prompt: "Drop a CoreML model here")
                .onDrop { sources in
                    guard let firstItem = sources.first else { return }
                    let model = try MLModel(contentsOf: MLModel.compileModel(at: firstItem.url))
                    
                    Task { @MainActor in
                        self.model = model
                        dismiss()
                        applyML()
                    }
                }
                .frame(width: 400, height: 200)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Confidence: ")
                
                TextField("above which observations would be applied", text: $confidence)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .alert(manager: $alertManager)
        
    }
    
    func applyML() {
        guard let model = model else { return }
        document.apply(undoManager: undoManager) {
            let _document = document
            let staticConfidence: Double
            if let userConfidence = Double(confidence), userConfidence <= 1, userConfidence >= 0 {
                staticConfidence = userConfidence
            } else {
                staticConfidence = 0.8
            }
            
            Task.detached {
                for i in 0..<_document.annotations.count {
                    guard let result = await applyObjectDetectionML(to: _document.annotations[i].image, model: model) else {
                        Task { @MainActor in document.leftSideBarSelectedItem = [document.annotations[i].id] }
                        continue
                    }
                    let annotations = result.filter({ $0.confidence >= Float(staticConfidence) }).compactMap { item -> Annotation.Annotations? in
                        guard let label = item.labels.first?.identifier else { return nil }
                        let coordinate = Annotation.Annotations.Coordinate(from: item, in: _document.annotations[i].image)
                        return Annotation.Annotations.init(label: label, coordinates: coordinate)
                    }
                    
                    Task { @MainActor in
                        document.annotations[i].annotations.append(contentsOf: annotations)
                        
                        document.leftSideBarSelectedItem = [document.annotations[i].id]
                        document.scrollProxy?.scrollTo(document.annotations[i].id)
                    }
                }
            }
        }
    }
}


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
func applyObjectDetectionML(to image: NSImage, model: MLModel) async -> [VNRecognizedObjectObservation]? {
    guard image.size != NSSize.zero else { print("skip \(image)"); return nil }
    guard let image = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("skip \(image)"); return nil }
    
    let orientation = CGImagePropertyOrientation.up
    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
    
    let model = try! VNCoreMLModel(for: model)
    let request = VNCoreMLRequest(model: model)
    try! handler.perform([request])
    
    guard let results = request.results else { print("skip \(image): can not form request from current model"); return nil }
    let observations = results as! [VNRecognizedObjectObservation]
    guard !observations.isEmpty else { print("skip \(image): the classification array of \(observations) is empty"); return nil }
    
    return observations
}
