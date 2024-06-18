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
import Stratum

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
        
        /// Coordinate relative to image, origin at center, coordinate zero at bottom-left.
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
                var scaleFactor: Double // imageView / image
                var heightMargin: Double = 0
                var widthMargin: Double = 0
                
                guard let cgImage = imageView.image?.cgImage else { return nil }
                
                if Double(cgImage.width) / Double(cgImage.height) >= imageView.frame.width / imageView.frame.height {
                    scaleFactor = imageView.frame.width / Double(cgImage.width)
                    heightMargin = (imageView.frame.height - Double(cgImage.height) * scaleFactor) / 2
                } else {
                    scaleFactor = imageView.frame.height / Double(cgImage.height)
                    widthMargin = (imageView.frame.width - Double(cgImage.width) * scaleFactor) / 2
                }
                
                let x = (frame.origin.x - widthMargin + frame.width / 2) / scaleFactor
                let y = (imageView.frame.height - (frame.origin.y + frame.height / 2) - heightMargin) / scaleFactor
                let width = frame.width / scaleFactor
                let height = frame.height / scaleFactor
                
                self.init(center: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
            }
            
            /// change the coordinate from that of a imageView to that of an image.
            init(from frame: CGRect, by imageView: NSView, image: NSImage) {
                var scaleFactor: Double // imageView / image
                var heightMargin: Double = 0
                var widthMargin: Double = 0
                
                let cgImage = image.cgImage!
                
                if Double(cgImage.width) / Double(cgImage.height) >= imageView.frame.width / imageView.frame.height {
                    scaleFactor = imageView.frame.width / Double(cgImage.width)
                    heightMargin = (imageView.frame.height - Double(cgImage.height) * scaleFactor) / 2
                } else {
                    scaleFactor = imageView.frame.height / Double(cgImage.height)
                    widthMargin = (imageView.frame.width - Double(cgImage.width) * scaleFactor) / 2
                }
                
                let x = (frame.origin.x - widthMargin + frame.width / 2) / scaleFactor
                let y = (imageView.frame.height - (frame.origin.y + frame.height / 2) - heightMargin) / scaleFactor
                let width = frame.width / scaleFactor
                let height = frame.height / scaleFactor
                
                let rawFrame = CGRect(center: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
                let intersect = rawFrame.intersection(CGRect(origin: .zero, size: cgImage.size))
                self.init(center: intersect.center, size: intersect.size)
            }
            
            // init from the coordinate from that of a observation
            /// Initializes the coordinate from Object Observation and coordinate in a `NSView`.
            init(from observation: VNRecognizedObjectObservation, in image: NSImage) {
                self.init(from: observation, in: image.cgImage!)
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
        var scaleFactor: Double // imageView / image
        var heightMargin: Double = 0
        var widthMargin: Double = 0
        
        let cgImage = imageView.image!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        
        if Double(cgImage.width) / Double(cgImage.height) >= imageView.frame.width / imageView.frame.height {
            scaleFactor = imageView.frame.width / Double(cgImage.width)
            heightMargin = (imageView.frame.height - Double(cgImage.height) * scaleFactor) / 2
        } else {
            scaleFactor = imageView.frame.height / Double(cgImage.height)
            widthMargin = (imageView.frame.width - Double(cgImage.width) * scaleFactor) / 2
        }
        
        let x = coordinate.x * scaleFactor + widthMargin
        let y = -1 * (coordinate.y * scaleFactor + heightMargin - imageView.frame.height)
        let width = coordinate.width * scaleFactor
        let height = coordinate.height * scaleFactor
        
        self.init(center: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }
    
    /// change the coordinate from createML image to CGImage. ie, center to bottom-left
    init(from coordinate: Annotation.Annotations.Coordinate) {
        self.init(x: coordinate.x - coordinate.width / 2, y: coordinate.y - coordinate.height / 2, width: coordinate.width, height: coordinate.height)
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
