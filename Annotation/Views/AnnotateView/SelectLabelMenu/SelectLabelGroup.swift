//
//  SelectLabelGroup.swift
//  Annotation
//
//  Created by Vaida on 6/19/24.
//

import SwiftUI


struct SelectLabelGroup: View {
    
    @EnvironmentObject private var document: AnnotationDocument
    
    let node: SelectLabelGroupedMenu.GroupedNode
    
    var body: some View {
        switch node {
        case .root(let children):
            ForEach(children.sorted(by: { $0.title < $1.title }), id: \.self) { node in
                SelectLabelGroup(node: node)
            }
        case .children(let head, let children):
            Menu(head) {
                ForEach(children.sorted(by: { $0.title < $1.title }), id: \.self) { node in
                    SelectLabelGroup(node: node)
                }
            }
        case .leaf(let word):
            Button {
                document.selectedLabel = word.0
            } label: {
                Text(word.1[0])
                    .foregroundStyle(word.0.color)
            }
        }
    }
}
