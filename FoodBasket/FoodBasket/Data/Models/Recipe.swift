//
//  Recipe.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

@Model
final class Recipe {
    var id: UUID = UUID()
    var name: String = ""
    var method: String = ""
    var cookingTimeMinutes: Int = 0
    var serves: Int = 0
    var rating: Int = 0
    var externalURL: URL?
    @Attribute(.externalStorage) var photoData: Data?
    var mealType: MealType?

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredientLines: [RecipeIngredient]? = []

    @Relationship(deleteRule: .nullify, inverse: \PlannedMeal.recipe)
    var plannedMeals: [PlannedMeal]? = []

    init(
        id: UUID = UUID(),
        name: String,
        method: String = "",
        cookingTimeMinutes: Int = 0,
        serves: Int = 0,
        rating: Int = 0,
        externalURL: URL? = nil,
        photoData: Data? = nil,
        mealType: MealType? = nil,
        ingredientLines: [RecipeIngredient]? = [],
        plannedMeals: [PlannedMeal]? = []
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.cookingTimeMinutes = cookingTimeMinutes
        self.serves = serves
        self.rating = rating
        self.externalURL = externalURL
        self.photoData = photoData
        self.mealType = mealType
        self.ingredientLines = ingredientLines
        self.plannedMeals = plannedMeals
    }
}

@Model
final class MealType {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Recipe.mealType)
    var recipes: [Recipe]? = []

    init(
        id: UUID = UUID(),
        name: String,
        recipes: [Recipe]? = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedLookupValue
        self.recipes = recipes
    }
}

@Model
final class RecipeIngredient {
    var id: UUID = UUID()
    var quantity: Double = 0
    var preparationMethod: String = ""
    var sortOrder: Int = 0
    var recipe: Recipe?
    var ingredient: Ingredient?

    init(
        id: UUID = UUID(),
        quantity: Double,
        preparationMethod: String = "",
        sortOrder: Int = 0,
        recipe: Recipe? = nil,
        ingredient: Ingredient? = nil
    ) {
        self.id = id
        self.quantity = quantity
        self.preparationMethod = preparationMethod
        self.sortOrder = sortOrder
        self.recipe = recipe
        self.ingredient = ingredient
    }
}
