//
//  IngredientImageViews.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import SwiftUI
import UIKit

struct IngredientDetailImageView: View {
    let photoData: Data?

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)

                    Image(systemName: "carrot")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .containerRelativeFrame(.horizontal) { width, _ in
            width / 3
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct IngredientThumbnailView: View {
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

                    Image(systemName: "carrot")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

#Preview("Ingredient Detail Image") {
    IngredientDetailImageView(photoData: nil)
        .padding()
}

#Preview("Ingredient Thumbnail") {
    IngredientThumbnailView(photoData: nil)
        .padding()
}
