//
//  IngredientImagePlayground.swift
//  Food Basket
//
//  Created by Codex on 17/6/2026.
//

import Foundation
import UIKit

enum IngredientImagePlayground {
    static func prompt(for ingredientName: String) -> String {
        "A simple centered illustration of \(ingredientName), isolated on a plain background"
    }

    static func photoData(from imageURL: URL) -> Data? {
        guard
            let imageData = try? Data(contentsOf: imageURL),
            let image = UIImage(data: imageData)
        else {
            return nil
        }

        return image.recipePhotoData
    }
}
