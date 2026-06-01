//
//  UIImage+RecipePhotoData.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import UIKit

extension UIImage {
    var recipePhotoData: Data? {
        resizedForRecipePhoto().jpegData(compressionQuality: 0.82)
    }

    private func resizedForRecipePhoto(maxDimension: CGFloat = 1800) -> UIImage {
        let largestDimension = max(size.width, size.height)
        guard largestDimension > maxDimension else { return self }

        let scale = maxDimension / largestDimension
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
