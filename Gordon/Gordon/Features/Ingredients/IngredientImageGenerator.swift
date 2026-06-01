//
//  IngredientImageGenerator.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import ImagePlayground
import UIKit

enum IngredientImageGenerator {
    static func generateImageData(for ingredientName: String) async -> Data? {
        do {
            let creator = try await ImageCreator()
            let style = creator.availableStyles.contains(.illustration)
                ? .illustration
                : creator.availableStyles.first

            guard let style else { return nil }

            let prompt = "A simple centered image of \(ingredientName), isolated on a plain background"
            let images = creator.images(
                for: [.text(prompt)],
                style: style,
                limit: 1
            )

            for try await image in images {
                return UIImage(cgImage: image.cgImage).recipePhotoData
            }
        } catch {
            return nil
        }

        return nil
    }
}

