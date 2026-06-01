//
//  Ingredient.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

@Model
final class Ingredient {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.unique) var normalizedName: String
    var defaultQuantity: Double
    @Attribute(.externalStorage) var photoData: Data?
    var category: IngredientCategory?
    var unit: MeasurementUnit?

    @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredient)
    var recipeLines: [RecipeIngredient]

    init(
        id: UUID = UUID(),
        name: String,
        defaultQuantity: Double = 1,
        photoData: Data? = nil,
        category: IngredientCategory? = nil,
        unit: MeasurementUnit? = nil,
        recipeLines: [RecipeIngredient] = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedLookupValue
        self.defaultQuantity = defaultQuantity
        self.photoData = photoData
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
