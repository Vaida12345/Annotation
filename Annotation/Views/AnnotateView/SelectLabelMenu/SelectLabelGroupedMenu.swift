//
//  SelectLabelGroupedMenu.swift
//  Annotation
//
//  Created by Vaida on 6/19/24.
//

import SwiftUI


struct SelectLabelGroupedMenu: View {
    
    @EnvironmentObject private var document: AnnotationDocument
    
    var body: some View {
        let labels = document.labels.values.map({ ($0, $0.title.split(separator: /[^a-zA-Z0-9]/)) })
        let node = GroupedNode(segmented: labels)
        let nodes = group(node: node)
        
        SelectLabelGroup(node: nodes)
    }
    
    
    typealias Word = (Dictionary<String, AnnotationDocument.Label>.Values.Element, [String.SubSequence])
    
    /// Creates a tree out of the headers of segments
    ///
    /// ```swift
    /// let value = [
    ///     "a.b.c",
    ///     "a.b.d",
    ///     "ab",
    /// ]
    ///
    /// let segmented = value.map({ $0.split(separator: /\W/) })
    ///
    /// Array.group(segmented: segmented)
    /// ```
    /// ```
    /// ─
    /// ├─a
    /// │ ╰─b
    /// │   ├─d
    /// │   ╰─c
    /// ╰─ab
    /// ```
    func group(node: GroupedNode) -> GroupedNode {
        func groupNodes(nodes: [GroupedNode]) -> [GroupedNode] {
            // need to expand
            var dictionary: [String.SubSequence : [Word]] = [:]
            for element in nodes {
                switch element {
                case .children, .root:
                    fatalError()
                case .leaf(let array):
                    if let first = array.1.first {
                        dictionary[first, default: []].append((array.0, Array(array.1.dropFirst())))
                    }
                }
            }
            
            return dictionary.map { key, value in
                if value.count != 1 {
                    group(node: .children(head: key, children: value.map({ .leaf($0) })))
                } else {
                    GroupedNode.leaf((value.first!.0, [key]))
                }
            }
        }
        
        switch node {
        case .root(let node):
            return .root(groupNodes(nodes: node))
            
        case .children(let t, let node):
            // need to expand
            return .children(head: t, children: groupNodes(nodes: node))
            
        case .leaf:
            return node
        }
    }
    
    /// A node
    indirect enum GroupedNode: Hashable, CustomStringConvertible {
        
        case root([GroupedNode])
        
        /// A node
        ///
        /// ### Parameters
        ///
        /// - term head: The element in common
        /// - term children: The children
        case children(head: String.SubSequence, children: [GroupedNode])
        
        /// A leaf
        case leaf(Word)
        
        static func == (lhs: SelectLabelGroupedMenu.GroupedNode, rhs: SelectLabelGroupedMenu.GroupedNode) -> Bool {
            switch lhs {
            case .children(let lhead, let lchildren):
                switch rhs {
                case .children(let head, let children):
                    lhead == head && lchildren == children
                case .leaf:
                    false
                case .root:
                    false
                }
            case .leaf(let lword):
                switch rhs {
                case .children:
                    false
                case .leaf(let word):
                    lword == word
                case .root:
                    false
                }
            case .root(let root):
                switch rhs {
                case .root(let array):
                    root == array
                case .children:
                    false
                case .leaf:
                    false
                }
            }
        }
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .children(let head, let children):
                hasher.combine(head)
                hasher.combine(children)
            case .leaf(let word):
                hasher.combine(word.0)
                hasher.combine(word.1)
            case .root(let word):
                hasher.combine(word)
            }
        }
        
        var title: String {
            switch self {
            case .children:
                return ""
            case .leaf(let word):
                return String(word.1.first ?? "")
            case .root:
                return ""
            }
        }
        
        public var description: String {
            String.recursiveDescription(of: self) { source in
                switch source {
                case .root(let nodes):
                    nodes
                case .children(_, let nodes):
                    nodes
                case .leaf:
                    nil
                }
            } description: { source in
                switch source {
                case .root:
                    "GroupedNode"
                case .children(let t, _):
                    "\(t)"
                case .leaf(let leaf):
                    "\(leaf)"
                }
            }
        }
        
        
        init(segmented: [Word]) {
            self = .root(segmented.map { .leaf($0) })
        }
    }
}

#Preview {
    SelectLabelGroupedMenu()
        .environmentObject(AnnotationDocument.preview)
}

