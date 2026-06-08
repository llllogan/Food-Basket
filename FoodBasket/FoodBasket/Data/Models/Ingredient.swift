//
//  Ingredient.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

@Model
final class Ingredient {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var category: IngredientCategory?

    @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredient)
    var recipeLines: [RecipeIngredient]? = []

    init(
        id: UUID = UUID(),
        name: String,
        photoData: Data? = nil,
        category: IngredientCategory? = nil,
        recipeLines: [RecipeIngredient]? = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedLookupValue
        self.photoData = photoData
        self.category = category
        self.recipeLines = recipeLines
    }
}

@Model
final class IngredientCategory {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Ingredient.category)
    var ingredients: [Ingredient]? = []

    init(
        id: UUID = UUID(),
        name: String,
        ingredients: [Ingredient]? = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedLookupValue
        self.ingredients = ingredients
    }
}

@Model
final class MeasurementUnit {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""
    var symbol: String = ""

    @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.unit)
    var recipeLines: [RecipeIngredient]? = []

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        recipeLines: [RecipeIngredient]? = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedLookupValue
        self.symbol = symbol
        self.recipeLines = recipeLines
    }
}
