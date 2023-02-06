//
//  AutoDetectView.swift
//  Annotation
//
//  Created by Vaida on 2/4/23.
//

import SwiftUI
import Support
import Vision
import CoreImage

struct AutoDetectView: View {
    
    @State private var detectOption: DetectOption = .ObjectnessBasedSaliency
    @State private var detectProgress: DetectProgress = .initial
    @State private var alertManager = AlertManager()
    
    @State private var rawImages: [RawImage] = []
    
    @Binding var undoManager: UndoManager?
    
    @EnvironmentObject private var document: AnnotationDocument
    @StateObject private var autoDetectDocument: AutoDetectDocument = AutoDetectDocument()
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack {
            VStack {
                if !rawImages.isEmpty {
                    GalleryView(rowCount: 4, data: rawImages) { image in
                        Image(nativeImage: image.image)
                            .cornerRadius(10)
                            .aspectRatio(weight: (image.image.pixelSize?.height ?? 1) / (image.image.pixelSize?.width ?? 1))
                    }
                    .padding()
                }
            }
            .frame(width: 600, height: 400)
            .background(BlurredEffectView())
            
            VStack {
                Picker("Option", selection: $detectOption)
                    .disabled(detectProgress != .initial)
                
                Text(self.detectOption.description)
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack() {
                    Button("Discard") {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    if detectProgress == .applyingML {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    
                    Button {
                        switch detectProgress {
                        case .initial:
                            let option = self.detectOption
                            Task.detached {
                                do {
                                    let annotations = try await autoDetectDocument.applyML(option: option)
                                    guard !annotations.isEmpty else { throw ErrorManager("Cannot find any matching result") }
                                    
                                    let __croppedImages = await withTaskGroup(of: RawImage?.self) { group in
                                        for annotation in annotations {
                                            let image = annotation.image
                                            
                                            for _annotation in annotation.annotations {
                                                group.addTask {
                                                    guard let _image = trimImage(from: image, at: _annotation.coordinate),
                                                          let cgImage = _image.cgImage,
                                                          let _cgImage = cgImage.resized(to: cgImage.size.aspectRatio(extend: .width, to: 140)) else { return nil }
                                                    
                                                    return RawImage(annotationID: annotation.id, annotationsID: _annotation.id, image: NativeImage(cgImage: _cgImage))
                                                }
                                            }
                                        }
                                        
                                        return await group.makeAsyncIterator().allObjects(reservingCapacity: annotations.count).compacted()
                                    }
                                    
                                    Task { @MainActor in
                                        autoDetectDocument.annotations = annotations
                                        
                                        self.rawImages = __croppedImages
                                        self.detectProgress = .waitForSelection
                                        
                                        print("returned")
                                    }
                                } catch {
                                    Task { @MainActor in
                                        self.alertManager = AlertManager(error: error, defaultAction: {
                                            await dismiss()
                                        })
                                    }
                                }
                            }
                            
                            detectProgress = .applyingML
                        default:
                            break
                        }
                    } label: {
                        Text(detectProgress.nextTitle)
                    }
                    .disabled(detectProgress.continueDisabled)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 300, height: 400)
        }
        .task {
            self.autoDetectDocument.annotations = document.annotations.map { Annotation(id: $0.id, image: $0.image) }
        }
        .alert(manager: $alertManager)
    }
    
    enum DetectOption: String, CaseIterable {
        case AttentionBasedSaliency = "Attention Based Saliency"
        case ObjectnessBasedSaliency = "Objectness Based Saliency"
        case FaceRectangles = "Face Rectangles"
        case HumanRectangles = "Human Rectangles"
        case RecognizeAnimals = "Recognize Animals"
        
        var description: String {
            switch self {
            case .AttentionBasedSaliency:
                return "Identifies the parts of an image most likely to draw attention."
            case .ObjectnessBasedSaliency:
                return "Identifies the parts of an image most likely to represent objects."
            case .FaceRectangles:
                return "Finds faces within an image."
            case .HumanRectangles:
                return "Finds rectangular regions that contain people in an image."
            case .RecognizeAnimals:
                return "recognizes animals in an image."
            }
        }
    }
    
    enum DetectProgress {
        case initial
        case applyingML
        case waitForSelection
        
        var nextTitle: String {
            switch self {
            case .initial, .waitForSelection:
                return "continue"
                
            default:
                return "Loading"
            }
        }
        
        var continueDisabled: Bool {
            switch self {
            case .initial, .waitForSelection:
                return false
                
            default:
                return true
            }
        }
    }
    
    struct RawImage: Identifiable {
        
        let annotationID: UUID
        
        let annotationsID: UUID
        
        let image: NSImage
        
        let givenTag: String? = nil
        
        var id: UUID {
            annotationsID
        }
        
    }
}


final class AutoDetectDocument: ObservableObject {
    
    @Published var annotations: AnnotationDocument.Snapshot = []
    
    func applyML(option: AutoDetectView.DetectOption) throws -> AnnotationDocument.Snapshot {
        let annotations = annotations
        
        var result: AnnotationDocument.Snapshot = []
        result.reserveCapacity(annotations.count)
        
        for annotation in annotations {
            try autoreleasepool {
                let request: VNImageBasedRequest
                switch option {
                case .AttentionBasedSaliency:
                    request = VNGenerateAttentionBasedSaliencyImageRequest()
                case .ObjectnessBasedSaliency:
                    request = VNGenerateObjectnessBasedSaliencyImageRequest()
                case .FaceRectangles:
                    request = VNDetectFaceRectanglesRequest()
                case .HumanRectangles:
                    request = VNDetectHumanRectanglesRequest()
                case .RecognizeAnimals:
                    request = VNRecognizeAnimalsRequest()
                }
                
                guard let image = annotation.image.cgImage else { return }
                let requestHandler = VNImageRequestHandler(cgImage: image)
                
                try requestHandler.perform([request])
                
                
                let boundingBoxes: [CGRect]
                switch option {
                case .ObjectnessBasedSaliency, .AttentionBasedSaliency:
                    guard let results = request.results as? [VNSaliencyImageObservation] else { return }
                    let objects = results.compactMap(\.salientObjects).flatten()
                    boundingBoxes = objects.map(\.boundingBox)
                    
                case .FaceRectangles, .HumanRectangles, .RecognizeAnimals:
                    guard let results = request.results as? [VNFaceObservation] else { return }
                    boundingBoxes = results.map(\.boundingBox)
                }
                
                guard !boundingBoxes.isEmpty else { return }
                
                let coordinates = boundingBoxes.map { object in
                    let rect = VNImageRectForNormalizedRect(object, image.width, image.height)
                    return Annotation.Annotations.Coordinate(center: CGPoint(x: rect.center.x, y: image.size.height - rect.center.y), size: rect.size)
                }
                
                result.append(AnnotationDocument.Snapshot.Element(id: annotation.id, image: annotation.image, annotations: coordinates.map { Annotation.Annotations(label: UUID().uuidString, coordinates: $0) }))
            }
        }
        
        return result
    }
    
}
