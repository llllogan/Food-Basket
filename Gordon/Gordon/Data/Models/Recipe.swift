//
//  Recipe.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var name: String
    var method: String
    var cookingTimeMinutes: Int = 0
    var serves: Int = 0
    @Attribute(.externalStorage) var photoData: Data?

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredientLines: [RecipeIngredient]

    @Relationship(deleteRule: .nullify, inverse: \PlannedMeal.recipe)
    var plannedMeals: [PlannedMeal]

    init(
        id: UUID = UUID(),
        name: String,
        method: String = "",
        cookingTimeMinutes: Int = 0,
        serves: Int = 0,
        photoData: Data? = nil,
        ingredientLines: [RecipeIngredient] = [],
        plannedMeals: [PlannedMeal] = []
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.cookingTimeMinutes = cookingTimeMinutes
        self.serves = serves
        self.photoData = photoData
        self.ingredientLines = ingredientLines
        self.plannedMeals = plannedMeals
    }
}

@Model
final class RecipeIngredient {
    @Attribute(.unique) var id: UUID
    var quantity: Double
    var sortOrder: Int
    var recipe: Recipe?
    var ingredient: Ingredient?

    init(
        id: UUID = UUID(),
        quantity: Double,
        sortOrder: Int = 0,
        recipe: Recipe? = nil,
        ingredient: Ingredient? = nil
    ) {
        self.id = id
        self.quantity = quantity
        self.sortOrder = sortOrder
        self.recipe = recipe
        self.ingredient = ingredient
    }
}
