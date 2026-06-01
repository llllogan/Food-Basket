//
//  RecipePhotoViews.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import UIKit

struct RecipeThumbnailView: View {
    let photoData: Data?

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)

                    Image(systemName: "fork.knife")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

struct RecipeHeroImageView: View {
    let photoData: Data?
    let takePhoto: () -> Void

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)

//                    Image(systemName: "fork.knife")
//                        .font(.system(size: 30))
//                        .foregroundStyle(.tertiary)
                }
                .frame(height: 360)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Recipe Thumbnail") {
    RecipeThumbnailView(photoData: nil)
        .padding()
}

#Preview("Recipe Hero Image") {
    RecipeHeroImageView(photoData: nil, takePhoto: {})
}
