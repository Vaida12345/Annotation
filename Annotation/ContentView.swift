//
//  ContentView.swift
//  Annotation
//
//  Created by Vaida on 2/10/22.
//

import SwiftUI
import Cocoa

struct ContentView: View {
    
    // core
    @State var label = "label"
    @EnvironmentObject var document: AnnotationDocument
    
    // layout
    @State var leftSideBarSelectedItem: Annotation.ID? = nil
    @State var showInfoView = false
    @State var showLabelList = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        NavigationView {
            SideBar(selection: $leftSideBarSelectedItem)
            
            ZStack {
                if let item = $document.annotations.first(where: {$0.id == leftSideBarSelectedItem}) {
                    DetailView(annotation: item)
                } else {
                    VStack {
                        Image(systemName: "square.and.arrow.down.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(.all)
                            .frame(width: 100, height: 100, alignment: .center)
                        Text("Drag files or folder.")
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .padding(.all)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if showInfoView {
                    HStack {
                        Spacer()
                        if document.annotations.first(where: {$0.id == leftSideBarSelectedItem}) != nil {
                            InfoView(annotation: $document.annotations.first(where: {$0.id == leftSideBarSelectedItem})!)
                                .frame(width: 300)
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                } else if showLabelList {
                    HStack {
                        Spacer()
                        LabelList(leftSideBarSelectedItem: $leftSideBarSelectedItem)
                            .frame(width: 300)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers, location in
                for i in providers {
                    Task {
                        guard let result = try? await i.loadItem(forTypeIdentifier: "public.file-url", options: nil) else { return }
                        guard let urlData = result as? Data else { return }
                        guard let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                        await document.addItems(from: [url], undoManager: undoManager)
                    }
                }
                
                return true
            }
            .toolbar {
                
                Toggle(isOn: $showLabelList.animation()) {
                    Image(systemName: "tag")
                }
                .onChange(of: showLabelList) { newValue in
                    withAnimation {
                        guard newValue else { return }
                        showInfoView = false
                    }
                }
                .help("Show Label List")
                
                Toggle(isOn: $showInfoView.animation()) {
                    Image(systemName: "list.bullet")
                }
                .onChange(of: showInfoView) { newValue in
                    withAnimation {
                        guard newValue else { return }
                        showLabelList = false
                    }
                }
                .help("Show Info View")
                
            }
            
        }
    }
    
}

struct SideBar: View {
    
    // core
    @Binding var selection: Annotation.ID?
    @EnvironmentObject var document: AnnotationDocument
    
    // layout
    @State var isShowingImportDialog = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        
        List(selection: $selection) {
            ForEach(document.annotations) { annotation in
                SideBarItem(annotation: annotation)
                    .contextMenu {
                        Button("Remove") {
                            document.delete(item: annotation, undoManager: undoManager)
                        }
                        
                        Button("Add") {
                            isShowingImportDialog = true
                        }
                    }
            }
            .onMove { fromIndex, toIndex in
                document.moveItemsAt(offsets: fromIndex, toOffset: toIndex, undoManager: undoManager)
            }
            .onDelete { index in
                document.delete(offsets: index, undoManager: undoManager)
            }
            
            GroupBox {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                        Spacer()
                    }
                    Spacer()
                }
            }
            .onTapGesture {
                isShowingImportDialog = true
            }
            
        }
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    // It turned out that Appkit should be used to toggle sidebar
                    // https://sarunw.com/posts/how-to-toggle-sidebar-in-macos/
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers, location in
            for i in providers {
                Task {
                    guard let result = try? await i.loadItem(forTypeIdentifier: "public.file-url", options: nil) else { return }
                    guard let urlData = result as? Data else { return }
                    guard let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                    await document.addItems(from: [url], undoManager: undoManager)
                }
            }
            return true
        }
        .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.annotationProject, .folder, .movie, .quickTimeMovie, .image], allowsMultipleSelection: true) { result in
            guard let urls = try? result.get() else { return }
            Task {
                await document.addItems(from: urls, undoManager: undoManager)
            }
        }
        
    }
}

struct SideBarItem: View {
    
    @State var annotation: Annotation
    
    var body: some View {
        Image(nsImage: annotation.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .cornerRadius(5)
    }
}

struct DetailView: View {
    
    // core
    @Binding var annotation: Annotation
    @EnvironmentObject var document: AnnotationDocument
    
    // layout
    @State var showLabelSheet = false
    @State var currentLabel: String = "New Label"
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                AnnotationView(annotation: $annotation, label: $currentLabel, size: reader.size)
                
                HStack {
                    VStack {
                        Menu {
                            ForEach(document.annotations.labels, id: \.self) { label in
                                Button(label) {
                                    currentLabel = label
                                }
                            }
                            Button("New...") {
                                currentLabel = "New Label"
                                showLabelSheet = true
                            }
                        } label: {
                            Text(currentLabel)
                        }
                        .background(RoundedRectangle(cornerRadius: 5).fill(.ultraThinMaterial))
                        .frame(width: 100, height: 20)
                        .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showLabelSheet) {
            VStack {
                HStack {
                    Text("Name for label: ")
                    
                    Spacer()
                }
                TextField("Name for label", text: $currentLabel)
                    .onSubmit {
                        showLabelSheet = false
                    }
                HStack {
                    Spacer()
                    
                    Button("Done") {
                        showLabelSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(width: 400)
            }
            .padding()
        }
    }
}

struct InfoView: View {
    
    // core
    @Binding var annotation: Annotation
    
    var body: some View {
        List($annotation.annotations, id: \.self) { item in
            InfoViewItem(item: item, annotation: $annotation)
            Divider()
        }
    }
}

struct InfoViewItem: View {
    
    @Binding var item: Annotation.Annotations
    @Binding var annotation: Annotation
    @EnvironmentObject var document: AnnotationDocument
    
    @State var onEdit = false
    @State var showLabelSheet = false
    @State var newLabel = ""
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        HStack {
            InfoViewImage(annotation: annotation, coordinate: item.coordinates)
            HStack {
                VStack {
                    if !onEdit {
                        Text(item.label)
                            .font(.title3)
                    } else {
                        Menu {
                            ForEach(document.annotations.labels, id: \.self) { label in
                                Button(label) {
                                    document.apply(undoManager: undoManager) {
                                        item.label = label
                                    }
                                }
                            }
                            
                            Button("New...") {
                                showLabelSheet = true
                            }
                        } label: {
                            Text(item.label)
                        }
                        
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                HStack(alignment: .center) {
                    Image(systemName: "pencil")
                        .onTapGesture {
                            onEdit.toggle()
                        }
                    
                    Image(systemName: "trash")
                        .onTapGesture {
                            withAnimation {
                                document.apply(undoManager: undoManager) {
                                    annotation.annotations.removeAll(where: { $0 == item })
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showLabelSheet) {
            VStack {
                HStack {
                    Text("Name for label: ")
                    
                    Spacer()
                }
                TextField("Name for label", text: $newLabel)
                    .onSubmit {
                        document.apply(undoManager: undoManager) {
                            item.label = newLabel
                            showLabelSheet = false
                        }
                    }
                    .onAppear {
                        newLabel = item.label
                    }
                HStack {
                    Spacer()
                    
                    Button("Done") {
                        document.apply(undoManager: undoManager) {
                            item.label = newLabel
                            showLabelSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(width: 400)
            }
            .padding()
        }
    }
}

struct InfoViewImage: View {
    
    @State var annotation: Annotation
    @State var coordinate: Annotation.Annotations.Coordinate
    
    @State var image: NSImage? = nil
    
    var body: some View {
        if let image = image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 75, height: 75)
                .cornerRadius(5)
        } else {
            GroupBox{
                VStack {
                    HStack {
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(width: 75, height: 75)
            .task {
                image = await trimImage(from: annotation.image, at: coordinate)
            }
        }
    }
}

struct LabelList: View {
    
    // core
    @EnvironmentObject var document: AnnotationDocument
    
    @Binding var leftSideBarSelectedItem: Annotation.ID?
    
    @State var showLabelSheet = false
    @State var oldName: String = ""
    @State var newLabel: String = ""
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        List(document.annotations.labels, id: \.self) { label in
            VStack {
                HStack {
                    Text(label)
                    Image(systemName: "pencil")
                        .onTapGesture {
                            oldName = label
                            showLabelSheet = true
                        }
                    Spacer()
                    Image(systemName: "trash")
                        .onTapGesture {
                            document.apply(undoManager: undoManager) {
                                for index in 0..<document.annotations.count {
                                    document.annotations[index].annotations.removeAll(where: { $0.label == label })
                                }
                            }
                        }
                }
                
                LabelListItems(leftSideBarSelectedItem: $leftSideBarSelectedItem, label: label)
                
                Divider()
            }
        }
        .sheet(isPresented: $showLabelSheet) {
            VStack {
                HStack {
                    Text("Name for label: ")
                    
                    Spacer()
                }
                TextField(oldName, text: $newLabel)
                    .onSubmit {
                        document.apply(undoManager: undoManager) {
                            for i in 0..<document.annotations.count {
                                for ii in 0..<document.annotations[i].annotations.count {
                                    if document.annotations[i].annotations[ii].label == oldName {
                                        document.annotations[i].annotations[ii].label = newLabel
                                    }
                                }
                            }
                        }
                        
                        showLabelSheet = false
                    }
                    .onAppear {
                        newLabel = oldName
                    }
                HStack {
                    Spacer()
                    
                    Button("Done") {
                        document.apply(undoManager: undoManager) {
                            for i in 0..<document.annotations.count {
                                for ii in 0..<document.annotations[i].annotations.count {
                                    if document.annotations[i].annotations[ii].label == oldName {
                                        document.annotations[i].annotations[ii].label = newLabel
                                    }
                                }
                            }
                        }
                        
                        showLabelSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(width: 400)
            }
            .padding()
        }
    }
}

struct LabelListItems: View {
    
    @EnvironmentObject var document: AnnotationDocument
    @Binding var leftSideBarSelectedItem: Annotation.ID?
    @State var label: String
    
    var body: some View {
        
        if let labelsDictionary = document.annotations.labelDictionary[label] {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(labelsDictionary, id: \.1.description) { item in
                        LabelListItem(item: item)
                            .onTapGesture(count: 2) {
                                guard let index = document.annotations.firstIndex(where: { $0.image == item.0 }) else { return }
                                leftSideBarSelectedItem = document.annotations[index].id
                            }
                    }
                }
            }
        }
        
    }
}

struct LabelListItem: View {
    
    @State var image: NSImage? = nil
    @State var item: (NSImage, Annotation.Annotations.Coordinate)
    
    var body: some View {
        if let image = image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .cornerRadius(5)
        } else {
            GroupBox{
                VStack {
                    HStack {
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(width: 50, height: 50)
            .task {
                image = await trimImage(from: item.0, at: item.1)
            }
        }
    }
}
