//
//  Models.swift
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

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredientLines: [RecipeIngredient]

    @Relationship(deleteRule: .nullify, inverse: \PlannedMeal.recipe)
    var plannedMeals: [PlannedMeal]

    init(
        id: UUID = UUID(),
        name: String,
        method: String = "",
        ingredientLines: [RecipeIngredient] = [],
        plannedMeals: [PlannedMeal] = []
    ) {
        self.id = id
        self.name = name
        self.method = method
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

@Model
final class Ingredient {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.unique) var normalizedName: String
    var defaultQuantity: Double
    var category: IngredientCategory?
    var unit: MeasurementUnit?

    @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredient)
    var recipeLines: [RecipeIngredient]

    init(
        id: UUID = UUID(),
        name: String,
        defaultQuantity: Double = 1,
        category: IngredientCategory? = nil,
        unit: MeasurementUnit? = nil,
        recipeLines: [RecipeIngredient] = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedLookupValue
        self.defaultQuantity = defaultQuantity
        self.category = category
        self.unit = unit
        self.recipeLines = recipeLines
    }
}

@Model
final class IngredientCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.unique) var normalizedName: String

    @Relationship(deleteRule: .nullify, inverse: \Ingredient.category)
    var ingredients: [Ingredient]

    init(
        id: UUID = UUID(),
        name: String,
        ingredients: [Ingredient] = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedLookupValue
        self.ingredients = ingredients
    }
}

@Model
final class MeasurementUnit {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.unique) var normalizedName: String
    var symbol: String

    @Relationship(deleteRule: .nullify, inverse: \Ingredient.unit)
    var ingredients: [Ingredient]

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        ingredients: [Ingredient] = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedLookupValue
        self.symbol = symbol
        self.ingredients = ingredients
    }
}

@Model
final class WeekPlan {
    @Attribute(.unique) var id: UUID
    var weekStarting: Date

    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.weekPlan)
    var plannedMeals: [PlannedMeal]

    init(
        id: UUID = UUID(),
        weekStarting: Date,
        plannedMeals: [PlannedMeal] = []
    ) {
        self.id = id
        self.weekStarting = weekStarting
        self.plannedMeals = plannedMeals
    }
}

@Model
final class PlannedMeal {
    @Attribute(.unique) var id: UUID
    var quantityMultiplier: Double
    var sortOrder: Int
    var weekPlan: WeekPlan?
    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        quantityMultiplier: Double = 1,
        sortOrder: Int = 0,
        weekPlan: WeekPlan? = nil,
        recipe: Recipe? = nil
    ) {
        self.id = id
        self.quantityMultiplier = quantityMultiplier
        self.sortOrder = sortOrder
        self.weekPlan = weekPlan
        self.recipe = recipe
    }
}
