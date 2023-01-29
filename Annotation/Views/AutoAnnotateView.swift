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

struct AutoaAnnotateView: View {
    
    @Binding var isShowingModelDialog: Bool
    @Binding var confidence: String
    @Binding var model: MLModel?
    @Binding var leftSideBarSelectedItem: Set<Annotation.ID>
    
    @EnvironmentObject var document: AnnotationDocument
    @Environment(\.undoManager) var undoManager
    
    @State var alertManager = AlertManager()
    
    var body: some View {
        
        VStack {
            DropHandlerView(prompt: "Drop a CoreML model here")
                .onDrop { sources in
                    guard let firstItem = sources.first else { return }
                    let model = try MLModel(contentsOf: MLModel.compileModel(at: firstItem.url))
                    
                    Task { @MainActor in
                        self.model = model
                        isShowingModelDialog = false
                        applyML()
                    }
                }
                .frame(width: 400, height: 200)
            
            HStack {
                Button("Cancel") {
                    isShowingModelDialog = false
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
        print("start!")
        guard let model = model else { return }
        document.apply(undoManager: undoManager, oldItems: document.annotations)
        DispatchQueue(label: "annotator").async {
            for i in 0..<document.annotations.count {
                print(i)
                guard document.annotations[i].annotations.isEmpty else { DispatchQueue.main.async{ leftSideBarSelectedItem = [document.annotations[i].id] }; continue }
                guard let result = applyObjectDetectionML(to: document.annotations[i].image, model: model) else { DispatchQueue.main.async{ leftSideBarSelectedItem = [document.annotations[i].id] }; continue }
                var staticConfidence = 0.8
                if let userConfidence = Double(confidence), userConfidence <= 1, userConfidence >= 0 {
                    staticConfidence = userConfidence
                }
                DispatchQueue.main.async {
                    document.apply(undoManager: undoManager) {
                        document.annotations[i].annotations = result.filter({ $0.confidence >= Float(staticConfidence) }).map{
                            Annotation.Annotations.init(label: $0.labels.first!.identifier, coordinates: Annotation.Annotations.Coordinate(from: $0, in: document.annotations[i].image))
                        }
                    }
                    
                    leftSideBarSelectedItem = [document.annotations[i].id]
                }
            }
            
            DispatchQueue.main.async {
                leftSideBarSelectedItem.removeAll()
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
func applyObjectDetectionML(to image: NSImage, model: MLModel) -> [VNRecognizedObjectObservation]? {
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
