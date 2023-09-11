//
//  LabelList.swift
//  Annotation
//
//  Created by Vaida on 5/10/22.
//

import Foundation
import SwiftUI
import Support

struct LabelList: View {
    
    // core
    @EnvironmentObject var document: AnnotationDocument
    @Binding var showLabelList: Bool
    
    @State var showLabelSheet = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        List(Array(document.labels)) { label in
            VStack {
                HStack {
                    Text(label.title)
                        .font(.title)
                        .foregroundStyle(label.color)
                    
                    Image(systemName: "pencil")
                        .onTapGesture {
                            showLabelSheet = true
                        }
                        .sheet(isPresented: $showLabelSheet) {
                            RenameLabelView(oldLabel: label)
                        }
                    
                    Spacer()
                    Image(systemName: "trash")
                        .onTapGesture {
                            document.remove(undoManager: undoManager, label: label)
                        }
                }
                
                LabelListItems(label: label, showLabelList: $showLabelList)
                
                Divider()
            }
        }
    }
}

struct LabelListItems: View {
    
    @EnvironmentObject var document: AnnotationDocument
    @State var label: AnnotationDocument.Label
    @Binding var showLabelList: Bool
    
    @State private var innerView: [InnerViewElement] = []
    
    var body: some View {
        Group {
            if !innerView.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(innerView, id: \.item.annotationsID) { item in
                            LabelListItem(showLabelList: $showLabelList, item: item)
                                .frame(width: item.size.width, height: item.size.height)
                        }
                    }
                }
            } else {
                HStack {
                    Text("Loading preview")
                    
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                }
            }
        }
        .frame(height: LabelListItems.height)
        .task {
            Task.detached { @Sendable in
                guard let labelsDictionary = await document.annotations.labelDictionary[label.title] else { return }
                
                let _innerView = await withTaskGroup(of: InnerViewElement?.self) { group in
                    for item in labelsDictionary {
                        group.addTask {
                            guard let annotation = await document.annotations.first(where: { $0.id == item.annotationID }) else { return nil }
                            guard let annotations = annotation.annotations.first(where: { $0.id == item.annotationsID }) else { return nil }
                            
                            let size = annotations.coordinate.size.aspectRatio(extend: .height, to: LabelListItems.height)
                            guard let croppedImage = trimImage(from: annotation.image, at: annotations.coordinate) else { return nil }
                            guard let resizedImage = croppedImage.cgImage?.resized(to: size) else { return nil }
                            
                            return InnerViewElement(item: item, croppedImage: NativeImage(cgImage: resizedImage), size: size)
                        }
                    }
                    
                    var iterator = group.makeAsyncIterator()
                    return await iterator.allObjects(reservingCapacity: labelsDictionary.count).compacted()
                }
                
                Task { @MainActor in
                    print("load completes with \(_innerView.count)")
                    self.innerView = _innerView
                }
            }
        }
    }
    
    static let height: CGFloat = 200
    
    struct InnerViewElement {
        
        let item: Array<Annotation>.LabelDictionaryValue
        
        let croppedImage: NativeImage
        
        let size: CGSize
        
    }
}

struct LabelListItem: View {
    
    // core
    @EnvironmentObject var document: AnnotationDocument
    @Binding var showLabelList: Bool
    
    let item: LabelListItems.InnerViewElement
    
    @Environment(\.undoManager) var undoManager
    @Environment(\.dismiss) var dismiss
    
    var contextMenu: some View {
        Menu {
            Button("Show Image") {
                withAnimation {
                    document.selectedItems = [item.item.annotationID]
                    document.scrollProxy?.scrollTo(item.item.annotationID)
                    showLabelList = false
                }
            }
            
            Divider()
            
            Button("Remove") {
                withAnimation {
                    document.removeAnnotations(undoManager: undoManager, annotationID: item.item.annotationID, annotationsID: item.item.annotationsID)
                }
            }
        } label: {
            
        }
    }
    
    var body: some View {
        Image(nsImage: item.croppedImage)
            .cornerRadius(5)
            .contextMenu {
                contextMenu
            }
            .overlay(alignment: .topTrailing) {
                contextMenu
                    .menuStyle(.borderlessButton)
                    .frame(width: 10)
                    .padding(2)
                    .foregroundColor(.blue)
            }
    }
}
