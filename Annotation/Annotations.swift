//
//  Annotations.swift
//  Annotation
//
//  Created by Vaida on 2/8/22.
//

import Foundation
import Cocoa

struct Annotation: Equatable, Hashable, Identifiable {
    
    var id: UUID
    var image: NSImage
    var annotations: [Annotations]
    
    struct Annotations: Equatable, Hashable, Encodable, Decodable {
        
        var label: String
        var coordinates: Coordinate
        
        struct Coordinate: Equatable, Hashable, Encodable, Decodable, CustomStringConvertible {
            
            var x: Double
            var y: Double
            var width: Double
            var height: Double
            
            var description: String {
                return "(\(x), \(y), \(width), \(height))"
            }
            
            private init(center: CGPoint, size: CGSize) {
                self.x = center.x
                self.y = center.y
                self.width = size.width
                self.height = size.height
            }
            
            private init(fromUpperLeftCornerY: Double, x: Double, width: Double, height: Double) {
                self.x = x + width / 2
                self.y = fromUpperLeftCornerY + height / 2
                self.width = width
                self.height = height
            }
            
            /// change the coordinate from that of a imageView to that of an image.
            init(from frame: CGRect, by imageView: NSImageView) {
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
                
                let x = (frame.origin.x - widthMargin + frame.width / 2) / scaleFactor
                let y = (imageView.frame.height - (frame.origin.y + frame.height / 2) - heightMargin) / scaleFactor
                let width = frame.width / scaleFactor
                let height = frame.height / scaleFactor
                
                print(frame)
                print(scaleFactor)
                print(widthMargin, heightMargin)
                print("image size", cgImage.width, cgImage.height)
                print("Frame", imageView.frame)
                print("result", x, y, width, height)
                
                self.init(center: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
            }
            
            /// change the coordinate from that of a imageView to that of an image.
            init(from frame: CGRect, by imageView: NSView, image: NSImage) {
                var scaleFactor: Double // imageView / image
                var heightMargin: Double = 0
                var widthMargin: Double = 0
                
                let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
                
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
                
                print(frame)
                print(scaleFactor)
                print(widthMargin, heightMargin)
                print("image size", cgImage.width, cgImage.height)
                print("Frame", imageView.frame)
                print("result", x, y, width, height)
                
                self.init(center: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
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
}

extension Array where Element == Annotation {
    
    var labels: [String] {
        return self.reduce([String](), { $0.union($1.annotations.map{ $0.label }) })
    }
    
    /// \[label: \[(Image Name, Coordinate)\]\]
    var labelDictionary: [String: [(NSImage, Annotation.Annotations.Coordinate)]] {
        var dictionary: [String: [(NSImage, Annotation.Annotations.Coordinate)]] = [:]
        for i in self {
            let image = i.image
            for ii in i.annotations {
                let label = ii.label
                let coordinate = ii.coordinates
                if dictionary[label] == nil {
                    dictionary[label] = [(image, coordinate)]
                } else {
                    dictionary[label]!.append((image, coordinate))
                }
            }
        }
        
        return dictionary
    }
    
}

func trimImage(from image: NSImage, at coordinate: Annotation.Annotations.Coordinate) -> NSImage? {
    autoreleasepool {
        guard image.size != .zero else { return nil }
        let imageView = NSImageView(image: image)
        imageView.frame = CGRect(origin: .zero, size: image.size)
        let rect =  CGRect(from: coordinate, by: imageView)
        guard rect.size != .zero else { return nil }
        return image.trimmed(rect: rect)
    }
}
