//
//  MachineLearning.swift
//
//
//  Created by Vaida on 10/12/21.
//  Copyright © 2021 Vaida. All rights reserved.
//


import Foundation
import Cocoa
import CoreML
import Vision
import SwiftUI

/// Returns the ML result by applying an Image Classification ML model to an image.
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
///     - model: The Image Classification ML Classifier model.
///     - image: The image on which performs the ML.
///
/// - Returns: The class of the image; `nil` otherwise.
func applyImageClassificationML(to image: NSImage, model: MLModel, confidence: Float = 0.8) -> String? {
    guard image.size != NSSize.zero else { print("skip \(image)"); return nil }
    guard let image = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("skip \(image)"); return nil }
    
    let orientation = CGImagePropertyOrientation.up
    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
    
    let model = try! VNCoreMLModel(for: model)
    let request = VNCoreMLRequest(model: model)
    try! handler.perform([request])
    
    guard let results = request.results else { print("skip \(image): can not form request from current model"); return nil }
    let classifications = results as! [VNClassificationObservation]
    guard !classifications.isEmpty else { print("skip \(image): the classification array of \(classifications) is empty"); return nil }
    
    let topClassifications = classifications.prefix(2)
    let descriptions = topClassifications.map { classification -> String? in
        guard classification.confidence > confidence else { return nil }
        return "\(classification.identifier)"
    }
    return descriptions.first!
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

/// Finds the texts in an `image` with `Vision`.
///
/// - Attention: The return value is `nil` if there is no `cgImage` behind the `image` or the ML failed to generate any results.
///
/// - Parameters:
///     - languages: The languages to be recognized, use ISO language code, such as "zh-Hans", "en".
///     - languageCorrection: A boolean indicating whether `NL` would be used to improve results.
///     - image: The image to be extracted text from.
///
/// - Returns: The texts in the image; `nil` otherwise.
func findText(in image: NSImage, languages: [String]? = nil, languageCorrection: Bool = true) -> [String]? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("failed findText(in: \(image): no cgImage behind the given image!");  return nil }
    
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNRecognizeTextRequest()
    
    request.recognitionLevel = .accurate
    request.recognitionLanguages = languages ?? ["en"]
    request.usesLanguageCorrection = languageCorrection
    try! handler.perform([request])
    
    guard let results = request.results else { print("failed findText(in: \(image): can not form results"); return nil }
    let observations = results
    let recognizedStrings = observations.compactMap { observation in
        // Return the string of the top VNRecognizedText instance.
        return observation.topCandidates(1).first?.string
    }
    
    return recognizedStrings
}

extension CGRect {
    
    /// Initializes the coordinate from Object Observation and coordinate in a `NSView`.
    init(from observation: VNRecognizedObjectObservation, by view: NSView, in image: NSImage) {
        var scaleFactor: Double // imageView / image
        var heightMargin: Double = 0
        var widthMargin: Double = 0
        
        let pixelSize = image.pixelSize!
        
        if Double(pixelSize.width) / Double(pixelSize.height) >= view.frame.width / view.frame.height {
            scaleFactor = view.frame.width / Double(pixelSize.width)
            heightMargin = (view.frame.height - Double(pixelSize.height) * scaleFactor) / 2
        } else {
            scaleFactor = view.frame.height / Double(pixelSize.height)
            widthMargin = (view.frame.width - Double(pixelSize.width) * scaleFactor) / 2
        }
        
        var coordinate = observation.boundingBox
        coordinate.origin.x *= pixelSize.width
        coordinate.size.width *= pixelSize.width
        coordinate.origin.y *= pixelSize.height
        coordinate.size.height *= pixelSize.height
        
        let x = coordinate.origin.x * scaleFactor + widthMargin
        let y = coordinate.origin.y * scaleFactor + heightMargin
        let width = coordinate.width * scaleFactor
        let height = coordinate.height * scaleFactor
        
        self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }
    
}

//struct AnnotatedObjectDetectionView: View {
//
//    let image: NSImage
//    let model: MLModel
//    @Binding var observationStatus: ObservationStatus
//
//    @State var observations: [VNRecognizedObjectObservation]? = nil
//
//    var body: some View {
//        Group {
//            if observationStatus == .observing {
//                ZStack {
//                    Image(nsImage: image)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//
//                    Rectangle()
//                        .fill(.ultraThinMaterial)
//
//                    ProgressView()
//                        .progressViewStyle(.circular)
//                }
//            } else if observationStatus == .failed {
//                Text("Observation Failed")
//            } else {
//                GeometryReader { reader in
//                    ZStack {
//                        Image(nsImage: image)
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//
//                        AnnotatedView(size: reader.size, observations: observations!, image: image)
//                    }
//                }
//
//            }
//        }
//        .onAppear {
//            observationStatus = .observing
//            DispatchQueue(label: "ObjectDetection").async {
//                if let result = applyObjectDetectionML(to: image, model: model) {
//                    self.observations = result
//                    observationStatus = .completed
//                } else {
//                    observationStatus = .failed
//                }
//            }
//        }
//    }
//
//    enum ObservationStatus {
//        case observing, failed, completed
//    }
//
//    struct AnnotatedView: NSViewRepresentable {
//        typealias NSViewType = NSView
//
//        var size: CGSize
//        var observations: [VNRecognizedObjectObservation]
//        var image: NSImage
//
//        func makeNSView(context: Context) -> NSView {
//            return NSView(frame: CGRect(origin: .zero, size: size))
//        }
//
//        func updateNSView(_ nsView: NSView, context: Context) {
//            nsView.frame = CGRect(origin: .zero, size: size)
//            for i in observations {
//                drawAnnotation(annotation: i, on: nsView)
//            }
//        }
//
//        func drawAnnotation(annotation: VNRecognizedObjectObservation, on mainView: NSView) {
//            let rect = CGRect(from: annotation, by: mainView, in: image)
//            let view = NSView(frame: rect)
//            let layer = CALayer()
//            layer.borderWidth = 2
//            layer.borderColor = NSColor.green.cgColor
//            view.layer = layer
//            mainView.addSubview(view)
//
//            let label = NSHostingView(rootView: TextLabel(value: annotation.labels.first!.identifier, size: CGSize(width: rect.width, height: 20)))
//            label.frame = CGRect(x: view.frame.width-rect.width-2, y: view.frame.height-20, width: rect.width, height: 20)
//            view.addSubview(label)
//        }
//
//        struct TextLabel: View {
//            @State var value: String
//            @State var size: CGSize
//
//            var body: some View {
//                HStack {
//                    Text(value)
//                        .multilineTextAlignment(.trailing)
//                        .background {
//                            Rectangle()
//                                .fill(.ultraThinMaterial)
//                        }
//                }
//                .frame(width: size.width, height: size.height, alignment: .trailing)
//            }
//        }
//    }
//}
