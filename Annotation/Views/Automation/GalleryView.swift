//
//  GalleryView.swift
//  The ViewCollection Module
//
//  Created by Vaida on 2/7/23.
//  Copyright © 2019 - 2024 Vaida. All rights reserved.
//

import SwiftUI
import NativeImage


/// An gallery that shows items of different ratio properly.
///
/// **Example**
///
/// Show a gallery.
///
/// ```swift
/// GalleryView(itemsPerRow: 4) {
///     ForEach(images) { image in
///         Image(nativeImage: image)
///             .resizable()
///             .aspectRatio(contentMode: .fit)
///     }
/// }
/// ```
///
/// ![Gallery view for the given code](galleryView)
///
/// The size of the images will be adjusted automatically when the window size is changed.
public struct GalleryView: Layout {
    
    private let storage: Storage
    
    private let spacing: Spacing
    
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        
        if proposal == .zero, case let Storage.fixed(width: width) = storage {
            let sizes = subviews.map { $0.dimensions(in: .init(width: width, height: nil)) }
            return CGSize(
                width: max(sizes.map(\.width).max() ?? 0, width),
                height: sizes.reduce(0) { $0 + (spacing.vertical ?? 0) + $1.height }
            )
        }
        
        if let width = proposal.width, proposal.width != 0 {
            let idealCellWidth: Double = switch storage {
            case .flexible(let itemsPerRow):
                (width - Double(itemsPerRow - 1) * (spacing.horizontal ?? 0)) / Double(itemsPerRow)
            case .fixed(let width):
                width
            }
            
            let itemsPerRow: Int = {
                switch storage {
                case .flexible(let itemsPerRow):
                    return itemsPerRow
                case .fixed(let _width):
                    var value = Int(width / _width)
                    while Double(value) * _width + Double(value - 1) * (spacing.horizontal ?? 0) > width {
                        value -= 1
                    }
                    return max(value, 1)
                }
            }()
            
            let sizes = subviews.map { $0.dimensions(in: .init(width: idealCellWidth, height: nil)) }
            let indexes = calculateRows(itemsPerRow: itemsPerRow, sizes: sizes)
            
            let mappedRows = indexes.map { $0.map { sizes[$0] } }
            return CGSize(
                width: mappedRows.reduce(0) { $0 + (spacing.horizontal ?? 0) + ($1.map(\.width).max() ?? 0) },
                height: mappedRows.reduce(0) { max($0, $1.reduce(0) { $0 + (spacing.vertical ?? 0) + $1.height }) }
            )
            
        } else { // the ideal size
            switch storage {
            case .flexible(let itemsPerRow):
                let _sizes = subviews.map { $0.dimensions(in: .unspecified) }
                let __sizes = subviews.map { $0.dimensions(in: .zero) }
                let ___sizes = zip(_sizes, __sizes).filter { $0.0 != $0.1 }.map(\.0) // obtain the sizes that cannot be changed.
                let idealWidth = ___sizes.map(\.width).mean ?? _sizes.map(\.width).mean
                let sizes = subviews.map { $0.dimensions(in: .init(width: idealWidth, height: nil)) }
                let indexes = calculateRows(itemsPerRow: itemsPerRow, sizes: sizes)
                
                let mappedRows = indexes.map { $0.map { sizes[$0] } }
                return CGSize(
                    width: mappedRows.reduce(0) { $0 + (spacing.horizontal ?? 0)  + ($1.map(\.width).max() ?? 0) },
                    height: mappedRows.reduce(0) { max($0, $1.reduce(0) { $0 + (spacing.vertical ?? 0) + $1.height }) }
                )
                
            case .fixed(let idealCellWidth):
                let idealItemsPerRow = 4
                let sizes = subviews.map { $0.dimensions(in: .init(width: idealCellWidth, height: nil)) }
                let indexes = calculateRows(itemsPerRow: idealItemsPerRow, sizes: sizes)
                
                let mappedRows = indexes.map { $0.map { sizes[$0] } }
                return CGSize(
                    width: mappedRows.reduce(0) { $0 + (spacing.horizontal ?? 0)  + ($1.map(\.width).max() ?? 0) },
                    height: mappedRows.reduce(0) { max($0, $1.reduce(0) { $0 + (spacing.vertical ?? 0) + $1.height }) }
                )
            }
        }
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard !subviews.isEmpty else { return }
        
        let idealCellWidth: Double = switch storage {
        case .flexible(let itemsPerRow):
            (bounds.width - Double(itemsPerRow - 1) * (spacing.horizontal ?? 0)) / Double(itemsPerRow)
        case .fixed(let width):
            width
        }
        
        let itemsPerRow: Int = {
            switch storage {
            case .flexible(let itemsPerRow):
                return itemsPerRow
            case .fixed(let _width):
                var value = Int(bounds.width / _width)
                while Double(value) * _width + Double(value - 1) * (spacing.horizontal ?? 0) > bounds.width {
                    value -= 1
                }
                return max(value, 1)
            }
        }()
        
        let sizes = subviews.map { $0.dimensions(in: .init(width: idealCellWidth, height: nil)) }
        let columns = calculateRows(itemsPerRow: itemsPerRow, sizes: sizes)
        
        var cumulativeWidth: CGFloat = 0
        var pendingWidth: CGFloat = 0
        
        for column in columns {
            var cumulativeHeight: CGFloat = 0
            for element in column {
                subviews[element].place(at: bounds.origin + CGPoint(x: cumulativeWidth, y: cumulativeHeight), proposal: .init(width: idealCellWidth, height: nil))
                cumulativeHeight += sizes[element].height + (spacing.vertical ?? 0)
                pendingWidth = max(pendingWidth, sizes[element].width)
            }
            cumulativeWidth += pendingWidth + (spacing.horizontal ?? 0)
            pendingWidth = 0
        }
    }
    
    
    /// - Complexity: O(*n* log *n*)
    private func calculateRows(itemsPerRow: Int, sizes: [ViewDimensions]) -> [[Int]] {
        var result: [_DivideResult] = []
        result.reserveCapacity(itemsPerRow)
        for _ in 0..<itemsPerRow {
            result.append(_DivideResult())
        }
        
        let sources = sizes.enumerated().sorted { $0.element.height > $1.element.height }
        for source in sources {
            let _result = result.min { $0.sum < $1.sum }!
            _result.sum += source.element.height
            _result.elements.append(source.offset)
        }
        
        return result.map(\.elements)
    }
    
    
    private final class _DivideResult {
        
        var sum: CGFloat = 0
        
        var elements: [Int] = []
        
    }
    
    
    /// Initialize the vertical grid with items per row.
    public init(itemsPerRow: Int, spacing: Spacing = .init(horizontal: 5, vertical: 5)) {
        precondition(itemsPerRow >= 1)
        self.storage = .flexible(itemsPerRow: itemsPerRow)
        self.spacing = spacing
    }
    
    /// Initialize the vertical grid with the `width` of each item, and the `alignment` of the grouped content.
    ///
    /// - Important: The layout does not enforce the `width`, only giving the subviews a proposal. You can specify it using `frame` directly.
    public init(itemWidth width: CGFloat, spacing: Spacing = .init(horizontal: 5, vertical: 5)) {
        self.storage = .fixed(width: width)
        self.spacing = spacing
    }
    
    
    private enum Storage {
        
        case flexible(itemsPerRow: Int)
        
        case fixed(width: CGFloat)
        
    }
    
    /// The padding distance between items
    public struct Spacing: Equatable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, Sendable {
        
        public let horizontal: CGFloat?
        
        public let vertical: CGFloat?
        
        
        /// Provides an indication of spacings.
        ///
        /// - Parameters:
        ///   - horizontal: The horizontal spacing
        ///   - vertical: The vertical spacing
        public init(horizontal: CGFloat? = nil, vertical: CGFloat? = nil) {
            self.horizontal = horizontal
            self.vertical = vertical
        }
        
        public init(floatLiteral value: FloatLiteralType) {
            self.init(horizontal: value, vertical: value)
        }
        
        public init(integerLiteral value: IntegerLiteralType) {
            self.init(floatLiteral: FloatLiteralType(value))
        }
        
        /// Indicates no padding required.
        public static let none = Spacing(horizontal: nil, vertical: nil)
        
    }
    
}
