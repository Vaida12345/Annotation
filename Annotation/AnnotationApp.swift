//
//  AnnotationApp.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import CoreML
import UniformTypeIdentifiers
import Vision
import Support

@main
struct AnnotationApp: App {
    
    @State var document: AnnotationDocument = AnnotationDocument()
    @State var isShowingExportDialog = false
    @State var isShowingImportDialog = false
    @State var leftSideBarSelectedItem: Set<Annotation.ID> = []
    
    @State var isShowingModelImportDialog = false
    @State var isShowingModelDialog = false
    @State var model: MLModel? = nil
    @State var confidence = "0.8"
    
    @Environment(\.undoManager) var undoManager
    
    var body: some Scene {
        DocumentGroup(newDocument: { AnnotationDocument() }) { file in
            ContentView(leftSideBarSelectedItem: $leftSideBarSelectedItem)
                .onAppear {
                    self.document = file.document
                }
                .sheet(isPresented: $isShowingModelDialog, onDismiss: nil) {
                    VStack {
                        VStack {
                            Spacer()
                            
                            HStack {
                                Spacer()
                                
                                Image(systemName: "square.and.arrow.down.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(.all)
                                    .frame(width: 100, height: 100, alignment: .center)
                                
                                Spacer()
                            }
                            
                            Spacer()
                        }
                        .frame(width: 800, height: 400)
                        .onTapGesture {
                            isShowingModelDialog = true
                        }
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers, location in
                            Task {
                                for i in providers {
                                    // the priority doesn't work, as load item is recommended to run on main thread.
                                    guard let result = try? await i.loadItem(forTypeIdentifier: "public.file-url", options: nil) else { return }
                                    guard let urlData = result as? Data else { return }
                                    guard let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                                    do {
                                        try model = MLModel(contentsOf: MLModel.compileModel(at: url))
                                    } catch {
                                        
                                    }
                                    if model != nil {
                                        isShowingModelDialog = false
                                        applyML()
                                    }
                                }
                            }
                            
                            return true
                        }
                        
                        HStack {
                            Button("Cancel") {
                                isShowingModelDialog = false
                            }
                            
                            Spacer()
                            
                            Text("Confidence: ")
                            
                            TextField("above which observations would be applied", text: $confidence)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
                .fileImporter(isPresented: $isShowingModelDialog, allowedContentTypes: [UTType("com.apple.coreml.model")!, UTType("com.apple.coreml.mlpackage")!]) { result in
                    guard let url = try? result.get() else { return }
                    do {
                        try model = MLModel(contentsOf: MLModel.compileModel(at: url))
                    } catch {
                        
                    }
                    if model != nil {
                        isShowingModelDialog = false
                        applyML()
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .importExport) {
                Section {
                    Button("Import") {
                        isShowingImportDialog = true
                    }
                    .keyboardShortcut("i")
                    .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.annotationProject, .movie, .quickTimeMovie, .folder, .image], allowsMultipleSelection: true) { result in
                        guard let urls = try? result.get() else { return }
                        Task.detached(priority: .background) {
                            print("import")
                            await document.addItems(from: urls, undoManager: undoManager)
                        }
                    }
                    
                    Button("Export...") {
                        isShowingExportDialog = true
                    }
                    .keyboardShortcut("e")
                    .fileExporter(isPresented: $isShowingExportDialog, document: document, contentType: .folder, defaultFilename: "Annotation Export") { result in
                        guard let url = try? result.get() else { return }
                        FinderItem(at: url)?.setIcon(image: NSImage(imageLiteralResourceName: "Folder Icon"))
                    }
                }
            }
            
            CommandGroup(after: .pasteboard) {
                Section {
                    Menu {
                        Button("based on model...") {
                            isShowingModelDialog.toggle()
                        }
                    } label: {
                        Text("Annotate")
                    }
                }
            }
        }
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
                    document.annotations[i].annotations = result.filter({ $0.confidence >= Float(staticConfidence) }).map{
                        Annotation.Annotations.init(label: $0.labels.first!.identifier, coordinates: Annotation.Annotations.Coordinate(from: $0, in: document.annotations[i].image))
                    }
                    
                    leftSideBarSelectedItem = [document.annotations[i].id]
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
