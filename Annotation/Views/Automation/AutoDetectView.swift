//
//  AutoDetectView.swift
//  Annotation
//
//  Created by Vaida on 2/4/23.
//

import SwiftUI
import Vision
import CoreImage
import ViewCollection
import Essentials
import NativeImage


struct AutoDetectView: View {
    
    @State private var detectOption: DetectOption = .ObjectnessBasedSaliency
    @State private var confidence: Float = 0
    @State private var unannotatedImagesOnly = true
    
    @State private var detectProgress: DetectProgress = .initial
    
    @StateObject private var rawImages: RawImagesContainer = .init()
    
    @EnvironmentObject private var document: AnnotationDocument
    @StateObject private var autoDetectDocument: AutoDetectDocument = AutoDetectDocument()
    
    let globalUndoManager: UndoManager?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if !rawImages.images.filter({ $0.confidence > confidence }).isEmpty {
                    ScrollView {
                        GalleryView(itemsPerRow: 4) {
                            ForEach(rawImages.images.filter({ $0.confidence > confidence })) { image in
                                ZStack(alignment: .topTrailing) {
                                    Image(nativeImage: image.image)
                                        .cornerRadius(10)
                                    
                                    if let label = image.givenTag {
                                        Text(label.title)
                                            .foregroundStyle(label.color)
                                    }
                                }
                                .onTapGesture {
                                    guard detectProgress == .waitForSelection else { return }
                                    
                                    if image.givenTag != document.selectedLabel {
                                        rawImages.assign(label: document.selectedLabel, to: image, with: undoManager)
                                    } else {
                                        rawImages.assign(label: nil, to: image, with: undoManager)
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(minWidth: 600)
                    }
                    .background(BlurredEffectView())
                } else {
                    BlurredEffectView()
                        .frame(minWidth: 600)
                }
            }

            VStack(alignment: .leading) {
                Toggle("Unannotated Images Only", isOn: $unannotatedImagesOnly)
                    .disabled(detectProgress != .initial)
                    .foregroundStyle(detectProgress != .initial ? .tertiary : .primary)
                
                Picker("Option", selection: $detectOption)
                    .disabled(detectProgress != .initial)
                    .foregroundStyle(detectProgress != .initial ? .tertiary : .primary)
                
                Text(self.detectOption.description)
                    .font(.callout)
                    .foregroundStyle(detectProgress != .initial ? .tertiary : .secondary)
                
                if detectProgress >= .waitForConfidence {
                    HStack {
                        Text("Confidence")
                        Slider(value: $confidence)
                    }
                    .disabled(detectProgress != .waitForConfidence)
                    .foregroundStyle(detectProgress != .waitForConfidence ? .tertiary : .primary)
                    .transition(.push(from: .bottom))
                }
                
                if detectProgress >= .waitForSelection {
                    HStack {
                        Text("Select a label")
                        SelectLabelMenu()
                    }
                    
                    Text("Then click on images of this group")
                    
                    Button("Assign All") {
                        undoManager?.beginUndoGrouping()
                        for image in rawImages.images {
                            rawImages.assign(label: document.selectedLabel, to: image, with: undoManager)
                        }
                        undoManager?.endUndoGrouping()
                        undoManager?.setActionName("Assign all to \(document.selectedLabel.title)")
                    }
                }

                Spacer()

                HStack() {
                    Button("Discard") {
                        dismiss()
                    }

                    Spacer()

                    if detectProgress == .applyingML {
                        Text("Running ML...")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }

                    Button {
                        switch detectProgress {
                        case .initial:
                            let option = self.detectOption
                            Task {
                                await withErrorPresented("Failed to detect") {
                                    let annotations = try await autoDetectDocument.applyML(option: option, document: self.document, unannotatedImagesOnly: unannotatedImagesOnly)
                                    guard !annotations.isEmpty else { throw MLError.noMatch }
                                    
                                    let __croppedImages = await withTaskGroup(of: RawImagesContainer.RawImage?.self) { group in
                                        for annotation in annotations {
                                            let image = annotation.image
                                            
                                            for _annotation in annotation.annotations {
                                                group.addTask {
                                                    guard let _image = await trimImage(from: image, at: _annotation.coordinate),
                                                          let _cgImage = _image.resized(to: _image.size.aspectRatio(extend: .width, to: 140)) else { return nil }
                                                    
                                                    return RawImagesContainer.RawImage(annotationID: annotation.id, annotationsID: _annotation.id, image: NativeImage(cgImage: _cgImage), confidence: _annotation.confidence, rect: _annotation.body.coordinate)
                                                }
                                            }
                                        }
                                        
                                        return await group.compacted().sequence()
                                    }
                                    
                                    Task { @MainActor in
                                        autoDetectDocument.annotations = annotations
                                        
                                        self.rawImages.objectWillChange.send()
                                        self.rawImages.images = __croppedImages
                                        self.detectProgress = .waitForConfidence
                                    }
                                }
                            }

                            detectProgress = .applyingML
                            
                        case .waitForConfidence:
                            self.rawImages.objectWillChange.send()
                            self.rawImages.images = self.rawImages.images.filter({ $0.confidence > confidence })
                            detectProgress = .waitForSelection
                            
                        case .waitForSelection:
                            // merge
                            globalUndoManager?.setActionName("Merge from Auto Detect")
                            self.document.apply(undoManager: globalUndoManager) {
                                for image in rawImages.images {
                                    let index = self.document.annotations.firstIndex(where: { $0.id == image.annotationID })!
                                    guard let tag = image.givenTag else { continue }
                                    self.document.annotations[index].annotations.append(.init(label: tag.title, coordinates: image.rect))
                                }
                            }
                            dismiss()
                            
                        default:
                            break
                        }
                    } label: {
                        Text(detectProgress.nextTitle)
                            .padding(.horizontal, 2)
                    }
                    .disabled(detectProgress.continueDisabled)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 300)
            .frame(idealHeight: 400)
        }
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
    
    enum MLError: GenericError {
        
        case noMatch
        
        var title: String {
            "ML Error"
        }
        
        var message: String {
            switch self {
            case .noMatch:
                "Cannot find any matching result"
            }
        }
        
    }
    
    enum DetectProgress: Comparable {
        case initial
        case applyingML
        case waitForConfidence
        case waitForSelection
        
        var nextTitle: String {
            switch self {
            case .initial, .waitForConfidence:
                return "Continue"
                
            case .waitForSelection:
                return "Add"
                
            default:
                return "Loading"
            }
        }
        
        var continueDisabled: Bool {
            switch self {
            case .initial, .waitForConfidence, .waitForSelection:
                return false
                
            default:
                return true
            }
        }
    }
}


final class RawImagesContainer: ObservableObject {
    
    @Published var images: [RawImage] = []
    
    func assign(label: AnnotationDocument.Label?, to image: RawImage, with undoManager: UndoManager?) {
        guard let firstIndex = self.images.firstIndex(of: image) else { return }
        let oldLabel = self.images[firstIndex].givenTag
        self.objectWillChange.send()
        self.images[firstIndex].givenTag = label
        
        if let label {
            undoManager?.setActionName("Assign Label of \(label.title)")
        } else if let oldLabel {
            undoManager?.setActionName("Remove Label of \(oldLabel.title)")
        }
        
        
        undoManager?.registerUndo(withTarget: self) { document in
            document.assign(label: oldLabel, to: image, with: undoManager)
        }
    }
    
    struct RawImage: Identifiable, Equatable {
        
        /// parent ID
        let annotationID: UUID
        
        let annotationsID: UUID
        
        let image: NSImage
        
        var givenTag: AnnotationDocument.Label? = nil
        
        let confidence: Float
        
        let rect: Annotation.Annotations.Coordinate
        
        var id: UUID {
            annotationsID
        }
        
        static func == (lhs: RawImage, rhs: RawImage) -> Bool {
            lhs.id == rhs.id
        }
    }
    
}


final class AutoDetectDocument: ObservableObject {
    
    @Published var annotations: [IdentifiedAnnotation] = []
    
    func applyML(option: AutoDetectView.DetectOption, document: AnnotationDocument, unannotatedImagesOnly: Bool) throws -> [IdentifiedAnnotation] {
        let annotations = document.annotations.filter { unannotatedImagesOnly => $0.annotations.isEmpty }
        
        var result: [IdentifiedAnnotation] = []
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
                let confidence: [Float]
                switch option {
                case .ObjectnessBasedSaliency, .AttentionBasedSaliency:
                    guard let results = request.results as? [VNSaliencyImageObservation] else { return }
                    let objects = results.compactMap(\.salientObjects).flatten()
                    boundingBoxes = objects.map(\.boundingBox)
                    confidence = objects.map(\.confidence)
                    
                case .FaceRectangles, .HumanRectangles, .RecognizeAnimals:
                    guard let results = request.results as? [VNFaceObservation] else { return }
                    boundingBoxes = results.map(\.boundingBox)
                    confidence = results.map(\.confidence)
                }
                
                guard !boundingBoxes.isEmpty else { return }
                
                let coordinates = (0..<boundingBoxes.count).map { i in
                    let object = boundingBoxes[i]
                    let confidence = confidence[i]
                    let rect = VNImageRectForNormalizedRect(object, image.width, image.height)
                    return (Annotation.Annotations.Coordinate(center: CGPoint(x: rect.center.x, y: image.size.height - rect.center.y), size: rect.size), confidence)
                }
                
                result.append(IdentifiedAnnotation(id: annotation.id, image: annotation.image, annotations: coordinates.map { IdentifiedAnnotation._Annotation(body: Annotation.Annotations(label: UUID().uuidString, coordinates: $0.0), confidence:  $0.1) }))
            }
        }
        
        return result
    }
    
    
    struct IdentifiedAnnotation {
        
        let id: UUID
        let image: NSImage
        var annotations: [_Annotation]
        
        @dynamicMemberLookup
        struct _Annotation {
            
            let body: Annotation.Annotations
            
            let confidence: Float
            
            
            subscript<T>(dynamicMember dynamicMember: KeyPath<Annotation.Annotations, T>) -> T {
                self.body[keyPath: dynamicMember]
            }
            
        }
        
    }
    
}
