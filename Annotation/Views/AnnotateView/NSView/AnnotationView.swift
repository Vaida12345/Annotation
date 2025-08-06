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
    // layout
    let size: CGSize
    
    @EnvironmentObject var document: AnnotationDocument
    
    var annotations: [Annotation] {
        let date = Date()
        defer { print("Obtain AnnotationView annotations took \(date.distanceToNow())") }
        return document.annotations.filter({ document.selectedItems.contains($0.id) })
    }
    
//    var textField = NSTextField()
//    var annotationsViews: [NSView] = []

    func makeNSView(context: Context) -> NSView {
        let date = Date()
        defer { print("\(#function) took \(date.distanceToNow())") }
        
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        for image in annotations.compactMap({ $0.representation.image }) {
            let imageView: NSImageView = NSImageView()
            image.size = image.pixelSize!.aspectRatio(.fit, in: size)
            imageView.frame = CGRect(origin: .zero, size: size)
            imageView.image = image
            imageView.alphaValue = 1.0 / CGFloat(annotations.count)
            view.addSubview(imageView)
        }
        
        let viewController = ViewController(document: document)
        viewController.view = NSView(frame: CGRect(origin: .zero, size: size))
        viewController.annotationView = self
        
        viewController.viewDidLoad()
        view.addSubview(viewController.view)
        
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let date = Date()
        defer { print("\(#function) took \(date.distanceToNow())") }
        
        _ = nsView.subviews.map{ $0.removeFromSuperview() }
        
        let viewController = ViewController(document: document)
        viewController.view = NSView(frame: CGRect(origin: .zero, size: size))
        viewController.annotationView = self
        
        viewController.viewDidLoad()
        nsView.addSubview(viewController.view)
        
        for annotation in annotations {
            guard let image = annotation.representation.image else { continue }
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
        
        nsView.addSubview(viewController.view)
    }
    
    func drawAnnotation(annotation: Annotation.Annotations, on image: NSImageView) {
        guard !annotation.hidden else { return }
        let rect = CGRect(from: annotation.coordinate, by: image)
        let view = NSView(frame: rect)
        let layer = CALayer()
        layer.borderWidth = 2
        layer.borderColor = document.labels[annotation.label]?.color.cgColor ?? NSColor.green.cgColor
        view.layer = layer
        image.addSubview(view)
        
        let _label = document.labels[annotation.label] ?? .init(title: annotation.label, color: .gray)
        
        let label = NSHostingView(rootView: TextLabel(label: _label, size: CGSize(width: rect.width, height: 20)))
        label.frame = CGRect(x: view.frame.width-rect.width-2, y: view.frame.height-20, width: rect.width, height: 20)
        view.addSubview(label)
    }
    
    
    final class ViewController: NSViewController {
        
        var recognizerView = NSView()
        var recognizer = PanGestureRecognizer()
        var recognizerStartingPoint = NSPoint.zero
        var annotationView: AnnotationView? = nil
        
        var document: AnnotationDocument
        
        var gridCellView: GridCellView?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            recognizer = PanGestureRecognizer(target: self, mouseDown: { [self] in
                self.view.addSubview(recognizerView)
                self.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                recognizerStartingPoint = recognizer.location(in: self.view)
                
                gridCellView?.isHidden = false
            }, mouseDragged: { [weak self] in
                self?.recognizerView.layer?.borderWidth = 2
                self?.recognizerView.layer?.borderColor = NSColor.blue.cgColor
                
                guard let location = self?.recognizer.location(in: self?.view) else { return }
                guard let translation = self?.recognizer.translation(in: self?.view) else { return }
                guard let recognizerStartingPoint = self?.recognizerStartingPoint else { return }
                
                self?.recognizerView.frame = CGRect(x: [location.x, recognizerStartingPoint.x].sorted(by: <).first!, y: [location.y, recognizerStartingPoint.y].sorted(by: <).first!, width: abs(translation.x), height: abs(translation.y))
                
                if let view = self?.gridCellView {
                    view.center = location
                    view.setNeedsDisplay(view.bounds)
                }
            }, mouseUp: { [weak self] in
                self?.gridCellView?.isHidden = true
                guard let document = self?.document else { return } // all classes, no cost
                guard let recognizerView = self?.recognizerView else { return }
                guard let view = self?.view else { return }
                guard let label = self?.document.selectedLabel else { return }
                guard let undoManager = self?.undoManager else { return }
                guard self?.recognizerView.frame.size.__isValid ?? false else {
                    self?.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                    self?.recognizerView.removeFromSuperview()
                    self?.recognizerStartingPoint = NSPoint.zero
                    self?.document.objectWillChange.send()
                    return
                }
                
                undoManager.beginUndoGrouping()
                
                for item in document.selectedItems {
                    guard let index = document.annotations.firstIndex(where: { $0.id == item }) else { continue }
                    guard let pixelSize = document.annotations[index].representation.pixelSize else { continue }
                    
                    let coordinate = Annotation.Annotations.Coordinate(from: recognizerView.frame, by: view, pixelSize: pixelSize)
                    let annotation = Annotation.Annotations(label: label.title, coordinates: coordinate)
                    
                    document.appendAnnotations(undoManager: undoManager, annotationID: item, item: annotation)
                    
                    if label.title == "New Label", document.labels[label.title] == nil {
                        document.labels[label.title] = label
                    }
                }
                
                undoManager.endUndoGrouping()
                undoManager.setActionName("Annotate")
                
                self?.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                self?.recognizerView.removeFromSuperview()
                self?.recognizerStartingPoint = NSPoint.zero
            })
            self.view.addGestureRecognizer(recognizer)
            self.view.addSubview(recognizerView)
            
            // Add your main content view
            let mainContentView = NSView(frame: view.bounds)
            mainContentView.wantsLayer = true
            view.addSubview(mainContentView)
            
            // Create and add the grid cell view
            gridCellView = GridCellView(frame: self.view.bounds)
            mainContentView.addSubview(gridCellView!)
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


class GridCellView: NSView {
    
    var trackingArea : NSTrackingArea?
    
    var center = CGPoint(x: -1, y: -1)
    
    var showDrawings = false
    
    
    override func updateTrackingAreas() {
        if trackingArea != nil {
            self.removeTrackingArea(trackingArea!)
        }
        
        let options : NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard showDrawings else { return }
        
        NSColor.controlBackgroundColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.75
        
        path.move(to: NSPoint(x: 0, y: self.center.y))
        path.line(to: NSPoint(x: frame.width, y: self.center.y))
        path.stroke()
        
        path.move(to: NSPoint(x: self.center.x, y: 0))
        path.line(to: NSPoint(x: self.center.x, y: frame.height))
        path.stroke()
    }
    
    override func mouseEntered(with event: NSEvent) {
        showDrawings = true
        self.setNeedsDisplay(self.bounds)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        self.center = self.convert(event.locationInWindow, from: nil)
        self.setNeedsDisplay(self.bounds)
    }
    
    override func mouseExited(with event: NSEvent) {
        showDrawings = false
        self.setNeedsDisplay(self.bounds)
    }
}

extension CGSize {
    
    var __isValid: Bool {
        self.width > 10 && self.height > 10
    }
    
}

struct TextLabel: View {
    let label: AnnotationDocument.Label
    let size: CGSize
    
    var body: some View {
        HStack {
            Text(label.title)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(label.color)
        }
        .frame(width: size.width, height: size.height, alignment: .trailing)
    }
}


