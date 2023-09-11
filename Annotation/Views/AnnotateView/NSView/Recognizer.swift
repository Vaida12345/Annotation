//
//  Recognizer.swift
//  Annotation
//
//  Created by Vaida on 9/11/23.
//

import Foundation
import AppKit


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
