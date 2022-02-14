//
//  AnnotationApp.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import CoreML
import UniformTypeIdentifiers

@main
struct AnnotationApp: App {
    
    @State var document: AnnotationDocument = AnnotationDocument()
    @State var isShowingExportDialog = false
    @State var isShowingImportDialog = false
    @State var leftSideBarSelectedItem: Annotation.ID? = nil
    
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
                guard document.annotations[i].annotations.isEmpty else { DispatchQueue.main.async{ leftSideBarSelectedItem = document.annotations[i].id }; continue }
                guard let result = applyObjectDetectionML(to: document.annotations[i].image, model: model) else { DispatchQueue.main.async{ leftSideBarSelectedItem = document.annotations[i].id }; continue }
                var staticConfidence = 0.8
                if let userConfidence = Double(confidence), userConfidence <= 1, userConfidence >= 0 {
                    staticConfidence = userConfidence
                }
                DispatchQueue.main.async {
                    document.annotations[i].annotations = result.filter({ $0.confidence >= Float(staticConfidence) }).map{
                        Annotation.Annotations.init(label: $0.labels.first!.identifier, coordinates: Annotation.Annotations.Coordinate(from: $0, in: document.annotations[i].image))
                    }
                    
                    leftSideBarSelectedItem = document.annotations[i].id
                }
            }
        }
    }
}
