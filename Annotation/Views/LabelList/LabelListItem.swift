//
//  LabelListItem.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import Stratum
import ViewCollection


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
    
    var body: some View {
        ZStack {
            AsyncLoadedImage(frame: .square(200), contentMode: .fit, source: item.container, cornerRadius: 10)
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(width: 200, height: 200)
                .cornerRadius(10)
            
            AsyncLoadedImage(frame: .square(200), contentMode: .fit, source: item.croppedImage, cornerRadius: 0)
        }
        .contextMenu {
            contextMenuContents
        }
    }
}


struct AsyncLoadedImage: View {
    
    let frame: CGSize
    
    let contentMode: ContentMode
    
    let source: CGImage
    
    let cornerRadius: CGFloat
    
    
    struct Capture: Equatable {
        
        let frame: CGSize
        
        let contentMode: ContentMode
        
        let source: CGImage
        
        let cornerRadius: CGFloat
        
    }
    
    var body: some View {
        AsyncView(captures: Capture(frame: frame, contentMode: contentMode, source: source, cornerRadius: cornerRadius)) { capture in
            let frame = capture.frame
            let contentMode = capture.contentMode
            let source = capture.source
            let cornerRadius = capture.cornerRadius
            
            let imageSize = source.size.aspectRatio(contentMode, in: frame)
            let contextSize = frame
            
            let context = CGContext.createContext(size: contextSize, bitsPerComponent: source.bitsPerComponent, space: source.colorSpace!, withAlpha: true)
            
            context.interpolationQuality = .high
            
            let path = createRoundedRectPath(for: CGRect(center: contextSize.center       , size: imageSize), radius: cornerRadius)
            
            context.addPath(path)
            context.clip()
            
            context.draw(source, in: CGRect(center: contextSize.center, size: imageSize))
            return context.makeImage()
        } content: { (image: CGImage?) in
            if let image {
                Image(nativeImage: NativeImage(cgImage: image))
            }
        }
        .frame(width: frame.width, height: frame.height)
    }
    
    nonisolated func createRoundedRectPath(for rect: CGRect, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        // Start at the top left corner
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        
        // Add the top side
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        
        // Add the top right corner arc
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius,
                    startAngle: CGFloat(3 * Double.pi / 2), endAngle: CGFloat(0), clockwise: false)
        
        // Add the right side
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        
        // Add the bottom right corner arc
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius,
                    startAngle: CGFloat(0), endAngle: CGFloat(Double.pi / 2), clockwise: false)
        
        // Add the bottom side
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        
        // Add the bottom left corner arc
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius,
                    startAngle: CGFloat(Double.pi / 2), endAngle: CGFloat(Double.pi), clockwise: false)
        
        // Add the left side
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        
        // Add the top left corner arc
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius,
                    startAngle: CGFloat(Double.pi), endAngle: CGFloat(3 * Double.pi / 2), clockwise: false)
        
        path.closeSubpath()
        
        return path
    }
}


#Preview {
    withStateObserved(initial: false) { state in
        LabelListItems(label: AnnotationDocument.preview.labels.first!.value,
                       showLabelList: state)
        .frame(width: 300, height: 300)
        .padding(.all)
        .environmentObject(AnnotationDocument.preview)
    }
}
