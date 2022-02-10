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

    typealias NSViewType = NSImageView

    // core
    @Binding var annotation: Annotation
    /// The current label used
    @Binding var label: String
    
    // layout
    let size: CGSize
    
    var imageView: NSImageView = NSImageView()
    
    /// The vc taking charge of NSPanGestureRecognizer
    @State var viewController = ViewController(nibName: nil, bundle: nil)
    
//    var textField = NSTextField()
//    var annotationsViews: [NSView] = []

    func makeNSView(context: Context) -> NSImageView {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        let image = FinderItem(at: annotation.image).image!
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.image = image
        image.size = size
        
        viewController.viewDidLoad()
        imageView.addSubview(viewController.view)
        
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.label = label
        viewController.annotationView = self
        
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        _ = nsView.subviews.map{ $0.removeFromSuperview() }
        viewController.annotationView = self
        
        let image = FinderItem(at: annotation.image).image!
        nsView.image = image
        nsView.imageScaling = .scaleProportionallyUpOrDown
        nsView.frame = CGRect(origin: .zero, size: size)
        image.size = { ()-> CGSize in
            var scaleFactor: Double // imageView / image
            let frame = image.size
            let imageView = nsView
            
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            
            if Double(cgImage.width) / Double(cgImage.height) >= imageView.frame.width / imageView.frame.height {
                scaleFactor = imageView.frame.width / Double(cgImage.width)
            } else {
                scaleFactor = imageView.frame.height / Double(cgImage.height)
            }
            
            let width = frame.width * scaleFactor
            let height = frame.height * scaleFactor
            return CGSize(width: width, height: height)
        }()
        
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.label = label
        
        for i in annotation.annotations {
            drawAnnotation(annotation: i, on: nsView)
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
        
        let label = NSTextField(string: annotation.label)
        label.isEditable = false
        label.frame = CGRect(x: view.frame.width-100, y: view.frame.height-20, width: 100, height: 20)
        label.alignment = .right
        view.addSubview(label)
        label.backgroundColor = NSColor.gray.withAlphaComponent(0.1)
    }
    
    
    class ViewController: NSViewController {
        
        var recognizerView = NSView()
        var recognizer = PanGestureRecognizer()
        var recognizerStartingPoint = NSPoint.zero
        var label = "Label"
        var annotationView: AnnotationView? = nil
        
        override func viewDidLoad() {
            super.viewDidLoad()
            recognizer = PanGestureRecognizer(target: self, action: #selector(action))
            recognizer.touchesDidEnd = {
                self.annotationView!.annotation.annotations.append(Annotation.Annotations(label: self.label, coordinates: Annotation.Annotations.Coordinate(from: self.recognizerView.frame, by: self.view, image: FinderItem(at: self.annotationView!.annotation.image).image!)))
                
                self.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                self.recognizerView.removeFromSuperview()
                self.recognizerStartingPoint = NSPoint.zero
            }
            recognizer.touchesDidStart = { [self] in
                self.view.addSubview(recognizerView)
                self.recognizerView.frame = CGRect(origin: .zero, size: .zero)
                recognizerStartingPoint = recognizer.location(in: self.view)
            }
            self.view = NSView()
            self.view.addGestureRecognizer(recognizer)
            self.view.addSubview(recognizerView)
        }
        
        @objc func action() {

            recognizerView.layer?.borderWidth = 2
            recognizerView.layer?.borderColor = NSColor.blue.cgColor

            recognizerView.frame = CGRect(x: [recognizer.location(in: self.view).x, recognizerStartingPoint.x].sorted(by: <).first!, y: [recognizer.location(in: self.view).y, recognizerStartingPoint.y].sorted(by: <).first!, width: abs(recognizer.translation(in: self.view).x), height: abs(recognizer.translation(in: self.view).y))
            print(recognizerView.frame)
        }
        
    }
    
    class PanGestureRecognizer: NSPanGestureRecognizer {
        
        var touchesDidEnd: (()->())? = nil
        var touchesDidStart: (()->())? = nil
        
        override func mouseUp(with event: NSEvent) {
            super.mouseUp(with: event)
            if touchesDidEnd != nil {
                touchesDidEnd!()
            }
        }
        
        override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            if touchesDidStart != nil {
                touchesDidStart!()
            }
        }
        
    }

}


