//
//  FoodBasketSchema.swift
//  Food Basket
//
//  Created by Codex on 3/6/2026.
//

import Foundation
import SwiftData

enum FoodBasketDataSchema {
    static var current: Schema {
        Schema(versionedSchema: FoodBasketDataSchemaV4.self)
    }
}

enum FoodBasketDataMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            FoodBasketDataSchemaV1.self,
            FoodBasketDataSchemaV2.self,
            FoodBasketDataSchemaV3.self,
            FoodBasketDataSchemaV4.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: FoodBasketDataSchemaV1.self,
                toVersion: FoodBasketDataSchemaV2.self
            ),
            .custom(
                fromVersion: FoodBasketDataSchemaV2.self,
                toVersion: FoodBasketDataSchemaV3.self,
                willMigrate: { context in
                    let lines = try context.fetch(
                        FetchDescriptor<FoodBasketDataSchemaV2.RecipeIngredient>()
                    )

                    for line in lines where line.unit == nil {
                        line.unit = line.ingredient?.unit
                    }

                    try context.save()
                },
                didMigrate: nil
            ),
            .lightweight(
                fromVersion: FoodBasketDataSchemaV3.self,
                toVersion: FoodBasketDataSchemaV4.self
            ),
        ]
    }
}

enum FoodBasketDataSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            MealType.self,
            RecipeIngredient.self,
            Ingredient.self,
            IngredientCategory.self,
            MeasurementUnit.self,
            WeekPlan.self,
            PlannedMeal.self,
            PlannedMealPortion.self,
        ]
    }

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

        init() {}
    }

    @Model
    final class MealType {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""

        @Relationship(deleteRule: .nullify, inverse: \Recipe.mealType)
        var recipes: [Recipe]? = []

        init() {}
    }

    @Model
    final class RecipeIngredient {
        var id: UUID = UUID()
        var quantity: Double = 0
        var preparationMethod: String = ""
        var sortOrder: Int = 0
        var recipe: Recipe?
        var ingredient: Ingredient?
        var unit: MeasurementUnit?

        init() {}
    }

    @Model
    final class Ingredient {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""
        @Attribute(.externalStorage) var photoData: Data?
        var category: IngredientCategory?

        @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredient)
        var recipeLines: [RecipeIngredient]? = []

        init() {}
    }

    @Model
    final class IngredientCategory {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""

        @Relationship(deleteRule: .nullify, inverse: \Ingredient.category)
        var ingredients: [Ingredient]? = []

        init() {}
    }

    @Model
    final class MeasurementUnit {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""
        var symbol: String = ""

        @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.unit)
        var recipeLines: [RecipeIngredient]? = []

        init() {}
    }

    @Model
    final class WeekPlan {
        var id: UUID = UUID()
        var weekStarting: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.weekPlan)
        var plannedMeals: [PlannedMeal]? = []

        @Relationship(deleteRule: .cascade, inverse: \PlannedMealPortion.weekPlan)
        var plannedMealPortions: [PlannedMealPortion]? = []

        init() {}
    }

    @Model
    final class PlannedMeal {
        var id: UUID = UUID()
        var quantityMultiplier: Double = 1
        var sortOrder: Int = 0
        var createdAt: Date = Date()
        var weekPlan: WeekPlan?
        var recipe: Recipe?

        @Relationship(deleteRule: .cascade, inverse: \PlannedMealPortion.plannedMeal)
        var portions: [PlannedMealPortion]? = []

        init() {}
    }

    @Model
    final class PlannedMealPortion {
        var id: UUID = UUID()
        var dayOffset: Int = 0
        var sortOrder: Int = 0
        var weekPlan: WeekPlan?
        var plannedMeal: PlannedMeal?

        init() {}
    }
}

enum FoodBasketDataSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            MealType.self,
            RecipeIngredient.self,
            Ingredient.self,
            IngredientCategory.self,
            MeasurementUnit.self,
            WeekPlan.self,
            PlannedMeal.self,
            PlannedMealPortion.self,
        ]
    }
}

enum FoodBasketDataSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            MealType.self,
            RecipeIngredient.self,
            Ingredient.self,
            IngredientCategory.self,
            MeasurementUnit.self,
            WeekPlan.self,
            PlannedMeal.self,
            PlannedMealPortion.self,
        ]
    }

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

        init() {}
    }

    @Model
    final class MealType {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""

        @Relationship(deleteRule: .nullify, inverse: \Recipe.mealType)
        var recipes: [Recipe]? = []

        init() {}
    }

    @Model
    final class RecipeIngredient {
        var id: UUID = UUID()
        var quantity: Double = 0
        var preparationMethod: String = ""
        var sortOrder: Int = 0
        var recipe: Recipe?
        var ingredient: Ingredient?

        init() {}
    }

    @Model
    final class Ingredient {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""
        var defaultQuantity: Double = 1
        @Attribute(.externalStorage) var photoData: Data?
        var category: IngredientCategory?
        var unit: MeasurementUnit?

        @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredient)
        var recipeLines: [RecipeIngredient]? = []

        init() {}
    }

    @Model
    final class IngredientCategory {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""

        @Relationship(deleteRule: .nullify, inverse: \Ingredient.category)
        var ingredients: [Ingredient]? = []

        init() {}
    }

    @Model
    final class MeasurementUnit {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""
        var symbol: String = ""

        @Relationship(deleteRule: .nullify, inverse: \Ingredient.unit)
        var ingredients: [Ingredient]? = []

        init() {}
    }

    @Model
    final class WeekPlan {
        var id: UUID = UUID()
        var weekStarting: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.weekPlan)
        var plannedMeals: [PlannedMeal]? = []

        @Relationship(deleteRule: .cascade, inverse: \PlannedMealPortion.weekPlan)
        var plannedMealPortions: [PlannedMealPortion]? = []

        init() {}
    }

    @Model
    final class PlannedMeal {
        var id: UUID = UUID()
        var quantityMultiplier: Double = 1
        var sortOrder: Int = 0
        var createdAt: Date = Date()
        var weekPlan: WeekPlan?
        var recipe: Recipe?

        @Relationship(deleteRule: .cascade, inverse: \PlannedMealPortion.plannedMeal)
        var portions: [PlannedMealPortion]? = []

        init() {}
    }

    @Model
    final class PlannedMealPortion {
        var id: UUID = UUID()
        var dayOffset: Int = 0
        var sortOrder: Int = 0
        var weekPlan: WeekPlan?
        var plannedMeal: PlannedMeal?

        init() {}
    }
}

enum FoodBasketDataSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            MealType.self,
            RecipeIngredient.self,
            Ingredient.self,
            IngredientCategory.self,
            MeasurementUnit.self,
            WeekPlan.self,
            PlannedMeal.self,
            PlannedMealPortion.self,
        ]
    }

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

        init() {}
    }

    @Model
    final class MealType {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""

        @Relationship(deleteRule: .nullify, inverse: \Recipe.mealType)
        var recipes: [Recipe]? = []

        init() {}
    }

    @Model
    final class RecipeIngredient {
        var id: UUID = UUID()
        var quantity: Double = 0
        var preparationMethod: String = ""
        var sortOrder: Int = 0
        var recipe: Recipe?
        var ingredient: Ingredient?
        var unit: MeasurementUnit?

        init() {}
    }

    @Model
    final class Ingredient {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""
        var defaultQuantity: Double = 1
        @Attribute(.externalStorage) var photoData: Data?
        var category: IngredientCategory?
        var unit: MeasurementUnit?

        @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredient)
        var recipeLines: [RecipeIngredient]? = []

        init() {}
    }

    @Model
    final class IngredientCategory {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""

        @Relationship(deleteRule: .nullify, inverse: \Ingredient.category)
        var ingredients: [Ingredient]? = []

        init() {}
    }

    @Model
    final class MeasurementUnit {
        var id: UUID = UUID()
        var name: String = ""
        var normalizedName: String = ""
        var symbol: String = ""

        @Relationship(deleteRule: .nullify, inverse: \Ingredient.unit)
        var ingredients: [Ingredient]? = []

        @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.unit)
        var recipeLines: [RecipeIngredient]? = []

        init() {}
    }

    @Model
    final class WeekPlan {
        var id: UUID = UUID()
        var weekStarting: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.weekPlan)
        var plannedMeals: [PlannedMeal]? = []

        @Relationship(deleteRule: .cascade, inverse: \PlannedMealPortion.weekPlan)
        var plannedMealPortions: [PlannedMealPortion]? = []

        init() {}
    }

    @Model
    final class PlannedMeal {
        var id: UUID = UUID()
        var quantityMultiplier: Double = 1
        var sortOrder: Int = 0
        var createdAt: Date = Date()
        var weekPlan: WeekPlan?
        var recipe: Recipe?

        @Relationship(deleteRule: .cascade, inverse: \PlannedMealPortion.plannedMeal)
        var portions: [PlannedMealPortion]? = []

        init() {}
    }

    @Model
    final class PlannedMealPortion {
        var id: UUID = UUID()
        var dayOffset: Int = 0
        var sortOrder: Int = 0
        var weekPlan: WeekPlan?
        var plannedMeal: PlannedMeal?

        init() {}
    }
}
