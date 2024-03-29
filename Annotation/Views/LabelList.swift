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
        ScrollView(.vertical) {
            ForEach(document.labels.values.sorted()) { label in
                VStack {
                    HStack {
                        Text(label.title)
                            .font(.title)
                            .foregroundStyle(label.color)
                        
                        Spacer()
                        
                        Image(systemName: "pencil")
                            .onTapGesture {
                                showLabelSheet = true
                            }
                            .sheet(isPresented: $showLabelSheet) {
                                RenameLabelView(oldLabel: label, undoManager: undoManager)
                            }
                        
                        Image(systemName: "trash")
                            .onTapGesture {
                                document.remove(undoManager: undoManager, label: label)
                            }
                    }
                    
                    LabelListItems(label: label, showLabelList: $showLabelList)
                    
                    Divider()
                }
                .padding(.trailing)
            }
        }
        .padding(.leading)
    }
}

struct LabelListItems: View {
    
    @EnvironmentObject var document: AnnotationDocument
    @State var label: AnnotationDocument.Label
    @Binding var showLabelList: Bool
    
    @State private var labelsDictionaryValue: Array<Array<Annotation>.LabelDictionaryValue> = []
    
    @State private var innerView: [InnerViewElement] = []
    @State private var isCompleted = false
    
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
                if !isCompleted {
                    HStack {
                        Text("Loading preview")
                        
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding()
                    }
                } else {
                    Text("Empty")
                        .foregroundStyle(.gray)
                        .fontDesign(.rounded)
                        .fontWeight(.heavy)
                }
            }
        }
        .frame(height: LabelListItems.height)
        .task {
            defer { self.isCompleted = true }
            guard let labelsDictionaryValue = document.annotations.labelDictionary[label.title] else { return }
            
            await updateInnerViews(labelsDictionaryValue: labelsDictionaryValue)
        }
        .onChange(of: document.annotations) { annotations in
            guard self.isCompleted else { return } // not yet completed, do not put more stress
            defer { self.isCompleted = true }
            guard let labelsDictionaryValue = document.annotations.labelDictionary[label.title] else { return }
            guard self.labelsDictionaryValue != labelsDictionaryValue else { return }
            self.isCompleted = false
            self.innerView = []
            
            Task {
                await updateInnerViews(labelsDictionaryValue: labelsDictionaryValue)
            }
        }
    }
    
    func updateInnerViews(labelsDictionaryValue: Array<Array<Annotation>.LabelDictionaryValue>) async {
        let _innerView = await withTaskGroup(of: InnerViewElement?.self) { group in
            for item in labelsDictionaryValue {
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
            return await iterator.allObjects(reservingCapacity: labelsDictionaryValue.count).compacted()
        }
        
        Task { @MainActor in
            self.labelsDictionaryValue = labelsDictionaryValue
            self.innerView = _innerView
            self.isCompleted = true
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
    
    @ViewBuilder
    var contextMenuContents: some View {
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
    }
    
    var contextMenu: some View {
        Menu {
            contextMenuContents
        } label: {
            
        }
    }
    
    var body: some View {
        Image(nsImage: item.croppedImage)
            .cornerRadius(5)
            .contextMenu {
                contextMenuContents
            }
    }
}
