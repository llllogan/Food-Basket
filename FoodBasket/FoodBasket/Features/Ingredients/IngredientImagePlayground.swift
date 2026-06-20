//
//  IngredientImagePlayground.swift
//  Food Basket
//
//  Created by Codex on 17/6/2026.
//

import Foundation
import UIKit

enum IngredientImagePromptDefaults {
    static let templateKey = "ingredientImagePromptTemplate"
    static let ingredientNameToken = "ingredient_name"
    static let defaultTemplate = "A simple centered illustration of ingredient_name, isolated on a plain background"

    static var savedTemplate: String {
        let template = FoodBasketSharedContainer.string(forKey: templateKey) ?? defaultTemplate
        guard isValid(template) else {
            return defaultTemplate
        }

        return template
    }

    static func isValid(_ template: String) -> Bool {
        template.contains(ingredientNameToken)
    }
}

enum IngredientImagePlayground {
    static func prompt(for ingredientName: String) -> String {
        IngredientImagePromptDefaults.savedTemplate.replacingOccurrences(
            of: IngredientImagePromptDefaults.ingredientNameToken,
            with: ingredientName
        )
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

enum RecipeImagePromptDefaults {
    static let templateKey = "recipeImagePromptTemplate"
    static let recipeNameToken = "recipe_name"
    static let ingredientListToken = "ingredient_list"
    static let defaultTemplate = "A simple centered illustration of recipe_name, showing the finished meal on a plain background"

    static var savedTemplate: String {
        let template = FoodBasketSharedContainer.string(forKey: templateKey) ?? defaultTemplate
        guard isValid(template) else {
            return defaultTemplate
        }

        return template
    }

    static func isValid(_ template: String) -> Bool {
        template.contains(recipeNameToken)
    }
}

enum RecipeImagePlayground {
    static func prompt(for recipeName: String, ingredientNames: [String]) -> String {
        let ingredients = ingredientNames.isEmpty
            ? "the recipe ingredients"
            : ingredientNames.joined(separator: ", ")

        return RecipeImagePromptDefaults.savedTemplate
            .replacingOccurrences(
                of: RecipeImagePromptDefaults.recipeNameToken,
                with: recipeName
            )
            .replacingOccurrences(
                of: RecipeImagePromptDefaults.ingredientListToken,
                with: ingredients
            )
    }

    static func photoData(from imageURL: URL) -> Data? {
        IngredientImagePlayground.photoData(from: imageURL)
    }
}
