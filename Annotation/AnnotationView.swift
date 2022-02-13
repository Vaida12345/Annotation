//
//  AnnotationView.swift
//  Annotation
//
//  Created by Vaida on 2/8/22.
//

import Foundation
import Cocoa
import SwiftUI

struct AnnotationView: NSViewRepresentable {

    typealias NSViewType = NSView

    // core
    @Binding var annotation: Annotation
    /// The current label used
    @Binding var label: String
    
    // layout
    let size: CGSize
    
    @EnvironmentObject var document: AnnotationDocument
    
//    var textField = NSTextField()
//    var annotationsViews: [NSView] = []

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        let imageView: NSImageView = NSImageView()
//        imageView.imageScaling = .scaleProportionallyUpOrDown
        let image = annotation.image
        image.size = image.aspectRatioFit(in: size)
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.image = image
        
        let viewController = ViewController(document: document)
        viewController.viewDidLoad()
        imageView.addSubview(viewController.view)
        
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.label = label
        viewController.annotationView = self
        
        view.addSubview(imageView)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        _ = nsView.subviews.map{ $0.removeFromSuperview() }
        
        let viewController = ViewController(document: document)
        viewController.viewDidLoad()
        nsView.addSubview(viewController.view)
        
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.label = label
        viewController.annotationView = self
        
        viewController.annotationView = self
        viewController.document = document
        
//        nsView.imageScaling = .scaleProportionallyUpOrDown
        let image = annotation.image
        nsView.frame = CGRect(origin: .zero, size: size)
        image.size = image.aspectRatioFit(in: size)
        
        let imageView: NSImageView = NSImageView()
        //        imageView.imageScaling = .scaleProportionallyUpOrDown
        image.size = annotation.image.aspectRatioFit(in: size)
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.image =  annotation.image
        nsView.addSubview(imageView)
        
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.label = label
        
        for i in annotation.annotations {
            drawAnnotation(annotation: i, on: imageView)
        }
        nsView.addSubview(viewController.view)
    }
    
    func drawAnnotation(annotation: Annotation.Annotations, on image: NSImageView) {
        let rect = CGRect(from: annotation.coordinates, by: image)
        let view = NSView(frame: rect)
        let layer = CALayer()
        layer.borderWidth = 2
        layer.borderColor = NSColor.green.cgColor
        view.layer = layer
        image.addSubview(view)
        
        let label = NSHostingView(rootView: TextLabel(value: annotation.label, size: CGSize(width: rect.width, height: 20)))
        label.frame = CGRect(x: view.frame.width-rect.width-2, y: view.frame.height-20, width: rect.width, height: 20)
        view.addSubview(label)
    }
    
    
    final class ViewController: NSViewController {
        
        var recognizerView = NSView()
        var recognizer = PanGestureRecognizer()
        var recognizerStartingPoint = NSPoint.zero
        var label = "Label"
        var annotationView: AnnotationView? = nil
        
        @State var document: AnnotationDocument
        
        override func viewDidLoad() {
            super.viewDidLoad()
            recognizer = PanGestureRecognizer(target: self, mouseDown: { [self] in
                self.view.addSubview(recognizerView)
                self.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                recognizerStartingPoint = recognizer.location(in: self.view)
            }, mouseDragged: { [self] in
                recognizerView.layer?.borderWidth = 2
                recognizerView.layer?.borderColor = NSColor.blue.cgColor
                
                recognizerView.frame = CGRect(x: [recognizer.location(in: self.view).x, recognizerStartingPoint.x].sorted(by: <).first!, y: [recognizer.location(in: self.view).y, recognizerStartingPoint.y].sorted(by: <).first!, width: abs(recognizer.translation(in: self.view).x), height: abs(recognizer.translation(in: self.view).y))
                print(recognizerView.frame)
            }, mouseUp: { [self] in
                if self.recognizerView.frame.width >= 10 && self.recognizerView.frame.height >= 10 {
                    document.apply(undoManager: undoManager, action: {
                        self.annotationView!.annotation.annotations.append(Annotation.Annotations(label: self.label, coordinates: Annotation.Annotations.Coordinate(from: self.recognizerView.frame, by: self.view, image: self.annotationView!.annotation.image)))
                    })
                }
                
                self.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                self.recognizerView.removeFromSuperview()
                self.recognizerStartingPoint = NSPoint.zero
            })
            self.view = NSView()
            self.view.addGestureRecognizer(recognizer)
            self.view.addSubview(recognizerView)
        }
        
        init(document: AnnotationDocument) {
            self.document = document
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
    }

}

struct TextLabel: View {
    @State var value: String
    @State var size: CGSize
    
    var body: some View {
        HStack {
            Text(value)
                .multilineTextAlignment(.trailing)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
        }
        .frame(width: size.width, height: size.height, alignment: .trailing)
    }
}
