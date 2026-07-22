//
//  Annotations.swift
//  Annotation
//
//  Created by Vaida on 2/8/22.
//

import Foundation
import Cocoa
import SwiftUI
import Vision


struct Annotation: Equatable, Hashable, Identifiable {
    
    let id: UUID
    let image: NSImage
    var annotations: [Annotations]
    
    init(id: UUID = UUID(), image: NSImage, annotations: [Annotations] = []) {
        self.id = id
        self.image = image
        self.annotations = annotations
    }
    
    /// An annotation with rect and label.
    struct Annotations: Equatable, Hashable, Encodable, Decodable, Identifiable {
        
        let id: UUID
        var label: String
        var hidden = false
        let coordinate: Coordinate
        
        init(label: String, coordinates: Coordinate) {
            self.id = UUID()
            self.label = label
            self.coordinate = coordinates
        }
        
        var export: AnnotationExport.Annotations {
            return .init(label: label, coordinates: coordinate)
        }
        
        /// A rectangle in image pixels. `x` and `y` describe its center and the origin is at the image's top-left.
        struct Coordinate: Equatable, Hashable, Encodable, Decodable, CustomStringConvertible, Identifiable {
            
            var id: UUID
            var x: Double
            var y: Double
            var width: Double
            var height: Double
            
            var description: String {
                return "(center: \(x), \(y), \(width), \(height))"
            }
            
            var size: CGSize {
                CGSize(width: self.width, height: self.height)
            }

            var isValid: Bool {
                x.isFinite && y.isFinite && width.isFinite && height.isFinite && width > 0 && height > 0
            }
            
            func squareContainer() -> Coordinate {
                Coordinate(center: CGPoint(x: x, y: y), size: .square(max(width, height)))
            }
            
            private init(x: Double, y: Double, width: Double, height: Double) {
                self.x = x
                self.y = y
                self.width = width
                self.height = height
                self.id = UUID()
            }
            
            static func center(x: Double, y: Double, width: Double, height: Double) -> Coordinate {
                Coordinate(x: x, y: y, width: width, height: height)
            }
            
            public init(center: CGPoint, size: CGSize) {
                self.x = center.x
                self.y = center.y
                self.width = size.width
                self.height = size.height
                self.id = UUID()
            }
            
            private init(fromUpperLeftCornerY: Double, x: Double, width: Double, height: Double) {
                self.x = x + width / 2
                self.y = fromUpperLeftCornerY + height / 2
                self.width = width
                self.height = height
                self.id = UUID()
            }
            
            private init(fromLowerLeftCornerY: Double, x: Double, width: Double, height: Double) {
                self.x = x + width / 2
                self.y = fromLowerLeftCornerY - height / 2
                self.width = width
                self.height = height
                self.id = UUID()
            }
            
            /// change the coordinate from that of a imageView to that of an image.
            init?(from frame: CGRect, by imageView: NSImageView) {
                guard let image = imageView.image,
                      let coordinate = ImageCoordinateTransformer.coordinate(fromViewRect: frame, viewSize: imageView.bounds.size, image: image) else { return nil }
                self = coordinate
            }
            
            /// change the coordinate from that of a imageView to that of an image.
            init(from frame: CGRect, by imageView: NSView, image: NSImage) {
                self = ImageCoordinateTransformer.coordinate(fromViewRect: frame, viewSize: imageView.bounds.size, image: image)
                    ?? Coordinate(center: .zero, size: .zero)
            }
            
            // init from the coordinate from that of a observation
            /// Initializes the coordinate from Object Observation and coordinate in a `NSView`.
            init(from observation: VNRecognizedObjectObservation, in image: NSImage) {
                if let cgImage = image.cgImage {
                    self.init(from: observation, in: cgImage)
                } else {
                    self.init(center: .zero, size: .zero)
                }
            }
            
            /// Initializes the coordinate from Object Observation and coordinate in a `NSView`.
            init(from observation: VNRecognizedObjectObservation, in image: CGImage) {
                
                let pixelSize = image.size
                
                var frame = observation.boundingBox
                frame.origin.x *= pixelSize.width
                frame.size.width *= pixelSize.width
                frame.origin.y *= pixelSize.height
                frame.size.height *= pixelSize.height
                
                let x = (frame.origin.x + frame.width / 2)
                let y = pixelSize.height - (frame.origin.y + frame.height / 2)
                let width = frame.width
                let height = frame.height
                
                self.init(center: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
            }
            
            
            // MARK: - Codable
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Annotation.Annotations.Coordinate.CodingKeys.self)
                try container.encode(self.x, forKey: Annotation.Annotations.Coordinate.CodingKeys.x)
                try container.encode(self.y, forKey: Annotation.Annotations.Coordinate.CodingKeys.y)
                try container.encode(self.width, forKey: Annotation.Annotations.Coordinate.CodingKeys.width)
                try container.encode(self.height, forKey: Annotation.Annotations.Coordinate.CodingKeys.height)
            }
            
            enum CodingKeys: CodingKey {
                case id
                case x
                case y
                case width
                case height
            }
            
            init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<Annotation.Annotations.Coordinate.CodingKeys> = try decoder.container(keyedBy: Annotation.Annotations.Coordinate.CodingKeys.self)
                self.x = try container.decode(Double.self, forKey: Annotation.Annotations.Coordinate.CodingKeys.x)
                self.y = try container.decode(Double.self, forKey: Annotation.Annotations.Coordinate.CodingKeys.y)
                self.width = try container.decode(Double.self, forKey: Annotation.Annotations.Coordinate.CodingKeys.width)
                self.height = try container.decode(Double.self, forKey: Annotation.Annotations.Coordinate.CodingKeys.height)
                
                self.id = UUID()
            }
        }
    }
}

extension CGRect {
    
    /// change the coordinate from that of an image to that of a imageView.
    init(from coordinate: Annotation.Annotations.Coordinate, by imageView: NSImageView) {
        self = imageView.image.map {
            ImageCoordinateTransformer.viewRect(from: coordinate, viewSize: imageView.bounds.size, image: $0)
        } ?? .zero
    }
    
    /// change the coordinate from createML image to CGImage. ie, center to bottom-left
    init(from coordinate: Annotation.Annotations.Coordinate) {
        self.init(x: coordinate.x - coordinate.width / 2, y: coordinate.y - coordinate.height / 2, width: coordinate.width, height: coordinate.height)
    }
}

enum ImageCoordinateTransformer {
    private static func geometry(viewSize: CGSize, image: NSImage) -> (scale: CGFloat, xMargin: CGFloat, yMargin: CGFloat, pixelSize: CGSize)? {
        guard viewSize.width > 0, viewSize.height > 0, let cgImage = image.cgImage else { return nil }
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        let scale = min(viewSize.width / pixelSize.width, viewSize.height / pixelSize.height)
        return (scale, (viewSize.width - pixelSize.width * scale) / 2, (viewSize.height - pixelSize.height * scale) / 2, pixelSize)
    }

    static func coordinate(fromViewRect rect: CGRect, viewSize: CGSize, image: NSImage) -> Annotation.Annotations.Coordinate? {
        guard let geometry = geometry(viewSize: viewSize, image: image), geometry.scale > 0 else { return nil }
        let center = CGPoint(
            x: (rect.midX - geometry.xMargin) / geometry.scale,
            y: (viewSize.height - rect.midY - geometry.yMargin) / geometry.scale
        )
        let raw = CGRect(center: center, size: CGSize(width: rect.width / geometry.scale, height: rect.height / geometry.scale))
        let clipped = raw.intersection(CGRect(origin: .zero, size: geometry.pixelSize))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
        return .init(center: clipped.center, size: clipped.size)
    }

    static func viewRect(from coordinate: Annotation.Annotations.Coordinate, viewSize: CGSize, image: NSImage) -> CGRect {
        guard coordinate.isValid, let geometry = geometry(viewSize: viewSize, image: image) else { return .zero }
        return CGRect(center: CGPoint(
            x: coordinate.x * geometry.scale + geometry.xMargin,
            y: viewSize.height - coordinate.y * geometry.scale - geometry.yMargin
        ), size: CGSize(width: coordinate.width * geometry.scale, height: coordinate.height * geometry.scale))
    }
}

extension Array where Element == Annotation {
    
    var __labels: [String] {
        self.flatMap { $0.annotations.map(\.label) }.unique()
    }
    
    var labelDictionary: [String: Array<LabelDictionaryValue>] {
        get async {
            var dictionary: [String: Array<LabelDictionaryValue>] = [:]
            dictionary.reserveCapacity(self.map(\.annotations.count).sum)
            
            for i in self {
                for ii in i.annotations {
                    let label = ii.label
                    if dictionary[label] == nil {
                        dictionary[label] = [LabelDictionaryValue(annotationID: i.id, annotationsID: ii.id)]
                    } else {
                        dictionary[label]!.append(LabelDictionaryValue(annotationID: i.id, annotationsID: ii.id))
                    }
                }
            }
            
            return dictionary
        }
    }
    
    func labelDictionary(of key: String) async -> [LabelDictionaryValue] {
        var results: [LabelDictionaryValue] = []
        
        for i in self {
            for ii in i.annotations {
                guard ii.label == key else { continue }
                results.append(LabelDictionaryValue(annotationID: i.id, annotationsID: ii.id))
            }
        }
        
        return results
    }
    
    struct LabelDictionaryValue: Equatable {
        
        let annotationID: Annotation.ID
        
        let annotationsID: Annotation.Annotations.ID
        
    }
    
}

nonisolated
func trimImage(from image: NSImage, at coordinate: Annotation.Annotations.Coordinate) async -> CGImage? {
    guard image.pixelSize != .zero else { return nil }
    let rect = CGRect(from: coordinate)
    guard rect.size != .zero else { return nil }
    
    guard let result = image.cgImage?.cropping(to: rect) else { return nil }
    return result
}
