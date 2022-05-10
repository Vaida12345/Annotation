//
//  AnnotationView.swift
//  Annotation
//
//  Created by Vaida on 2/8/22.
//

import Foundation
import Cocoa
import SwiftUI
import Support

struct AnnotationView: NSViewRepresentable {

    typealias NSViewType = NSView

    // core
    @Binding var leftSideBarSelectedItem: Set<Annotation.ID>
    /// The current label used
    @Binding var label: String
    
    // layout
    let size: CGSize
    
    @EnvironmentObject var document: AnnotationDocument
    
    var annotations: [Annotation] {
        return document.annotations.filter({ leftSideBarSelectedItem.contains($0.id) })
    }
    
//    var textField = NSTextField()
//    var annotationsViews: [NSView] = []

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        for image in annotations.map({ $0.image }) {
            let imageView: NSImageView = NSImageView()
            image.size = image.aspectRatioFit(in: size)
            imageView.frame = CGRect(origin: .zero, size: size)
            imageView.image = image
            imageView.alphaValue = 1.0 / CGFloat(annotations.count)
            view.addSubview(imageView)
        }
        
        let viewController = ViewController(document: document)
        viewController.viewDidLoad()
        view.addSubview(viewController.view)
        
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.label = label
        viewController.annotationView = self
        
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
        
        for annotation in annotations {
            let image = annotation.image
            let imageView: NSImageView = NSImageView()
            image.size = image.aspectRatioFit(in: size)
            imageView.frame = CGRect(origin: .zero, size: size)
            imageView.image = image
            imageView.alphaValue = 1.0 / CGFloat(annotations.count)
            nsView.addSubview(imageView)
            
            for i in annotation.annotations {
                drawAnnotation(annotation: i, on: imageView)
            }
        }
        
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.label = label
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
                        for i in self.annotationView!.leftSideBarSelectedItem {
                            let index = document.annotations.firstIndex(where: { $0.id == i })!
                            document.annotations[index].annotations.append(Annotation.Annotations(label: self.label, coordinates: Annotation.Annotations.Coordinate(from: self.recognizerView.frame, by: self.view, image: document.annotations[index].image)))
                        }
                        
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

/// A continuous gesture recognizer for panning gestures.
class PanGestureRecognizer: NSPanGestureRecognizer {
    
    var touchesDidStart: (()->())? = nil
    var touchesDragged: (()->())? = nil
    var touchesDidEnd: (()->())? = nil
    
    /// Creates an instance with its actions.
    ///
    /// - Parameters:
    ///    - mouseDown: Informs the gesture recognizer that the user pressed the left mouse button.
    ///    - mouseDragged: Informs the gesture recognizer that the user moved the mouse with the left button pressed.
    ///    - mouseUp: Informs the gesture recognizer that the user released the left mouse button.
    convenience init(target: Any?, mouseDown: (()->())? = nil, mouseDragged: (()->())? = nil, mouseUp: (()->())? = nil) {
        self.init(target: target, action: nil)
        self.touchesDidStart = mouseDown
        self.touchesDragged = mouseDragged
        self.touchesDidEnd = mouseUp
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        if touchesDidStart != nil {
            touchesDidStart!()
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        if touchesDragged != nil {
            touchesDragged!()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        if touchesDidEnd != nil {
            touchesDidEnd!()
        }
    }
    
}
