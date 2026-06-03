//
//  FoodBasketSchema.swift
//  Food Basket
//
//  Created by Codex on 3/6/2026.
//

import SwiftData

enum FoodBasketDataSchema {
    static var current: Schema {
        Schema([
            Recipe.self,
            RecipeIngredient.self,
            Ingredient.self,
            IngredientCategory.self,
            MeasurementUnit.self,
            WeekPlan.self,
            PlannedMeal.self,
            PlannedMealPortion.self,
        ])
    }
}
