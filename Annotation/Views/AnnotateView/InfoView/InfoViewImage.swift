//
//  InfoViewImage.swift
//  Annotation
//
//  Created by Vaida on 6/18/24.
//

import SwiftUI
import ViewCollection
import NativeImage


struct InfoViewImage: View {
    
    let annotation: Annotation
    let coordinate: Annotation.Annotations.Coordinate
    
    struct Capture: Equatable {
        let annotation: Annotation
        let coordinate: Annotation.Annotations.Coordinate
    }
    
    nonisolated func update() async -> (NativeImage, NativeImage) {
        
        let image = await NativeImage(cgImage: trimImage(from: annotation.image, at: coordinate)) ?? NativeImage()
        let container = await NativeImage(cgImage: trimImage(from: annotation.image, at: coordinate.squareContainer())) ?? NativeImage()
        return (image, container)
    }
    
    var body: some View {
        AsyncView(generator: update) { image, container in
            ZStack {
                Group {
                    Image(nativeImage: container)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .cornerRadius(3)
                }
                
                Image(nativeImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            }
        }
        .frame(width: 60, height: 60)
    }
}

#Preview {
    let preview = AnnotationDocument.preview.annotations.first!
    InfoViewImage(annotation: preview, coordinate: preview.annotations[0].coordinate)
        .frame(width: 120, height: 120)
        .padding(.all)
}
