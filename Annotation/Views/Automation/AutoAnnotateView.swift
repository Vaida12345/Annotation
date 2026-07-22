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
import ViewCollection
import Essentials


struct AutoAnnotateView: View {
    
    @State private var confidence: Double = 0.8
    @State private var model: MLModel?
    @State private var unannotatedImageOnly = true
    
    @Environment(AnnotationDocument.self) private var document
    @Environment(\.dismiss) var dismiss
    
    let undoManager: UndoManager?
    
    var body: some View {
        
        HStack {
            DropHandlerView(prompt: "Drop a CoreML model here")
                .onDrop { sources in
                    guard let firstItem = sources.first else { return }
                    Task { @MainActor in
                        await withErrorPresented("Failed to annotate") {
                            let compiledURL = try await MLModel.compileModel(at: firstItem.url)
                            let model = try MLModel(contentsOf: compiledURL)
                            self.model = model
                            try await applyML(using: model)
                            dismiss()
                        }
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
    
    @MainActor
    func applyML(using model: MLModel) async throws {
        let oldItems = document.annotations
        let oldLabels = document.labels.values.map { AnnotationDocument.Label(title: $0.title, color: $0.color) }
        let oldSelection = document.selectedItems
        self.document.selectedItems = []
        
        let _document = document
        let staticConfidence = confidence
        
        let _unannotatedImagesOnly = unannotatedImageOnly
        
        let images = _document.annotations.enumerated().compactMap { index, annotation in
            annotation.image.cgImage.map { (index: index, image: $0) }
        }
        
        for (i, image) in images {
            try Task.checkCancellation()
            if _unannotatedImagesOnly && !_document.annotations[i].annotations.isEmpty {
                continue
            }
            
            let result = try await applyObjectDetectionML(to: image, model: model)
            let annotations = result.filter({ $0.confidence >= Float(staticConfidence) }).compactMap { item -> Annotation.Annotations? in
                guard let label = item.labels.first?.identifier else { return nil }
                let coordinate = Annotation.Annotations.Coordinate(from: item, in: image)
                return Annotation.Annotations.init(label: label, coordinates: coordinate)
            }
            
            document.annotations[i].annotations.append(contentsOf: annotations)
            document.selectedItems = [document.annotations[i].id]
            document.scrollProxy?.scrollTo(document.annotations[i].id)
        }
        
        
        // synchronize labels
        let _labels = document.annotations.__labels
        let difference = Set(_labels).subtracting(document.labels.keys)
        for i in difference {
            document.labels[i] = .init(title: i, color: .green)
        }
        
        // undo / redo
        undoManager?.setActionName("Auto Annotate")
        undoManager?.registerUndo(withTarget: document) { document in
            document.replaceState(annotations: oldItems, labels: oldLabels, selection: oldSelection, undoManager: undoManager)
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
enum ObjectDetectionError: LocalizedError {
    case incompatibleModel
    case unsupportedResults
    case noResults

    var errorDescription: String? {
        switch self {
        case .incompatibleModel: "The selected Core ML model cannot be used by Vision."
        case .unsupportedResults: "The model does not produce object-detection observations."
        case .noResults: "The model did not detect any objects."
        }
    }
}

func applyObjectDetectionML(to image: CGImage, model coreMLModel: MLModel) async throws -> [VNRecognizedObjectObservation] {
    let orientation = CGImagePropertyOrientation.up
    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
    
    let model: VNCoreMLModel
    do {
        model = try VNCoreMLModel(for: coreMLModel)
    } catch {
        throw ObjectDetectionError.incompatibleModel
    }
    let request = VNCoreMLRequest(model: model)
    try handler.perform([request])
    
    guard let results = request.results else { throw ObjectDetectionError.noResults }
    guard let observations = results as? [VNRecognizedObjectObservation] else { throw ObjectDetectionError.unsupportedResults }
    guard !observations.isEmpty else { throw ObjectDetectionError.noResults }
    
    return observations
}
