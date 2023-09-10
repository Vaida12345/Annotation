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
    /// The current label used
    @Binding var label: Annotation.Label
    
    // layout
    let size: CGSize
    
    @EnvironmentObject var document: AnnotationDocument
    
    var annotations: [Annotation] {
        document.annotations.filter({ document.leftSideBarSelectedItem.contains($0.id) })
    }
    
//    var textField = NSTextField()
//    var annotationsViews: [NSView] = []

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        for image in annotations.map({ $0.image }) {
            let imageView: NSImageView = NSImageView()
            image.size = image.pixelSize!.aspectRatio(.fit, in: size)
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
        
        for annotation in annotations {
            let image = annotation.image
            let imageView: NSImageView = NSImageView()
            image.size = image.pixelSize!.aspectRatio(.fit, in: size)
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
        guard !annotation.hidden else { return }
        let rect = CGRect(from: annotation.coordinate, by: image)
        let view = NSView(frame: rect)
        let layer = CALayer()
        layer.borderWidth = 2
        layer.borderColor = annotation.label.color.cgColor ?? NSColor.green.cgColor
        view.layer = layer
        image.addSubview(view)
        
        let label = NSHostingView(rootView: TextLabel(label: annotation.label, size: CGSize(width: rect.width, height: 20)))
        label.frame = CGRect(x: view.frame.width-rect.width-2, y: view.frame.height-20, width: rect.width, height: 20)
        view.addSubview(label)
    }
    
    
    final class ViewController: NSViewController {
        
        var recognizerView = NSView()
        var recognizer = PanGestureRecognizer()
        var recognizerStartingPoint = NSPoint.zero
        var label = Annotation.Label(title: "Label", color: .gray)
        var annotationView: AnnotationView? = nil
        
        var document: AnnotationDocument
        
        var isShowingGrid = false
        var gridCellView: GridCellView?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            recognizer = PanGestureRecognizer(target: self, mouseDown: { [self] in
                self.view.addSubview(recognizerView)
                self.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                recognizerStartingPoint = recognizer.location(in: self.view)
            }, mouseDragged: { [weak self] in
                self?.recognizerView.layer?.borderWidth = 2
                self?.recognizerView.layer?.borderColor = NSColor.blue.cgColor
                
                guard let location = self?.recognizer.location(in: self?.view) else { return }
                guard let translation = self?.recognizer.translation(in: self?.view) else { return }
                guard let recognizerStartingPoint = self?.recognizerStartingPoint else { return }
                
                self?.recognizerView.frame = CGRect(x: [location.x, recognizerStartingPoint.x].sorted(by: <).first!, y: [location.y, recognizerStartingPoint.y].sorted(by: <).first!, width: abs(translation.x), height: abs(translation.y))
            }, mouseUp: { [weak self] in
                guard let document = self?.document else { return } // all classes, no cost
                guard let recognizerView = self?.recognizerView else { return }
                guard let view = self?.view else { return }
                guard let label = self?.label else { return }
                guard let undoManager = self?.undoManager else { return }
                guard self?.recognizerView.frame.size.__isValid ?? false else {
                    self?.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                    self?.recognizerView.removeFromSuperview()
                    self?.recognizerStartingPoint = NSPoint.zero
                    return
                }
                
                undoManager.setActionName("Annotate")
                undoManager.beginUndoGrouping()
                
                for item in document.leftSideBarSelectedItem {
                    guard let index = document.annotations.firstIndex(where: { $0.id == item }) else { continue }
                    
                    let coordinate = Annotation.Annotations.Coordinate(from: recognizerView.frame, by: view, image: document.annotations[index].image)
                    let annotation = Annotation.Annotations(label: label, coordinates: coordinate)
                    
                    document.appendAnnotations(undoManager: undoManager, annotationID: item, item: annotation)
                }
                
                undoManager.endUndoGrouping()
                
                self?.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                self?.recognizerView.removeFromSuperview()
                self?.recognizerStartingPoint = NSPoint.zero
            })
            self.view = NSView()
            self.view.addGestureRecognizer(recognizer)
            self.view.addSubview(recognizerView)
            
            // Add your main content view
            let mainContentView = NSView(frame: view.bounds)
            mainContentView.wantsLayer = true
            view.addSubview(mainContentView)
            
            // Create and add the grid cell view
            gridCellView = GridCellView(frame: self.view.bounds)
            gridCellView?.isHidden = true
            mainContentView.addSubview(gridCellView!)
        }
        
        init(document: AnnotationDocument) {
            self.document = document
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func mouseMoved(with event: NSEvent) {
            print("moved")
            if isShowingGrid {
                let mouseLocation = view.convert(event.locationInWindow, from: nil)
                gridCellView?.frame.origin = mouseLocation
            }
        }
        
        override func mouseEntered(with event: NSEvent) {
            isShowingGrid = true
            gridCellView?.isHidden = false
            mouseMoved(with: event)
        }
        
        override func mouseExited(with event: NSEvent) {
            isShowingGrid = false
            gridCellView?.isHidden = true
        }
        
    }

}


class GridCellView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        NSColor.green.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: frame.height / 2))
        path.line(to: NSPoint(x: frame.width, y: frame.height / 2))
        path.lineWidth = 2
        path.stroke()
        
        let path2 = NSBezierPath()
        path2.move(to: NSPoint(x: frame.width / 2, y: 0))
        path2.line(to: NSPoint(x: frame.width / 2, y: frame.height))
        path2.lineWidth = 2
        path2.stroke()
    }
    
    
}

extension CGSize {
    
    var __isValid: Bool {
        self.width > 10 && self.height > 10
    }
    
}

struct TextLabel: View {
    @State var label: Annotation.Label
    @State var size: CGSize
    
    var body: some View {
        HStack {
            Text(label.title)
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
