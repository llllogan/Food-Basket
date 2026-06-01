//
//  PreviewData.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

struct PreviewData {
    let container: ModelContainer
    let recipe: Recipe
    let ingredient: Ingredient

    init() {
        let schema = Schema([
            Recipe.self,
            RecipeIngredient.self,
            Ingredient.self,
            IngredientCategory.self,
            MeasurementUnit.self,
            WeekPlan.self,
            PlannedMeal.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }

        let modelContext = container.mainContext

        let produce = IngredientCategory(name: "Produce")
        let meat = IngredientCategory(name: "Meat")
        let pantry = IngredientCategory(name: "Pantry")
        let each = MeasurementUnit(name: "Each", symbol: "each")
        let gram = MeasurementUnit(name: "Gram", symbol: "g")

        let chicken = Ingredient(
            name: "Chicken thigh",
            defaultQuantity: 500,
            category: meat,
            unit: gram
        )
        let broccoli = Ingredient(
            name: "Broccoli",
            defaultQuantity: 1,
            category: produce,
            unit: each
        )
        let lemon = Ingredient(
            name: "Lemon",
            defaultQuantity: 1,
            category: produce,
            unit: each
        )
        let rice = Ingredient(
            name: "Basmati rice",
            defaultQuantity: 300,
            category: pantry,
            unit: gram
        )

        let lemonChicken = Recipe(
            name: "Lemon Chicken with Rice",
            method: "Roast the chicken with lemon, steam the broccoli, and serve with rice.",
            cookingTimeMinutes: 45,
            serves: 4
        )
        Self.add(chicken, quantity: 500, to: lemonChicken, in: modelContext)
        Self.add(lemon, quantity: 1, to: lemonChicken, in: modelContext)
        Self.add(broccoli, quantity: 1, to: lemonChicken, in: modelContext)
        Self.add(rice, quantity: 300, to: lemonChicken, in: modelContext)

        let broccoliRice = Recipe(
            name: "Broccoli Rice Bowl",
            method: "Steam the broccoli and serve over rice with your preferred dressing.",
            cookingTimeMinutes: 25,
            serves: 2
        )
        Self.add(broccoli, quantity: 2, to: broccoliRice, in: modelContext)
        Self.add(rice, quantity: 250, to: broccoliRice, in: modelContext)

        let weekStarting = Calendar.current.startOfWeek(containing: Date())
        let weekPlan = WeekPlan(weekStarting: weekStarting)
        Self.add(lemonChicken, quantityMultiplier: 1, to: weekPlan, in: modelContext)
        Self.add(broccoliRice, quantityMultiplier: 2, to: weekPlan, in: modelContext)

        for model in [
            produce,
            meat,
            pantry,
            each,
            gram,
            chicken,
            broccoli,
            lemon,
            rice,
            lemonChicken,
            broccoliRice,
            weekPlan,
        ] as [any PersistentModel] {
            modelContext.insert(model)
        }

        try? modelContext.save()

        recipe = lemonChicken
        ingredient = broccoli
    }

    private static func add(
        _ ingredient: Ingredient,
        quantity: Double,
        to recipe: Recipe,
        in modelContext: ModelContext
    ) {
        let line = RecipeIngredient(
            quantity: quantity,
            sortOrder: recipe.ingredientLines?.count ?? 0,
            ingredient: ingredient
        )
        recipe.ingredientLines = (recipe.ingredientLines ?? []) + [line]
        modelContext.insert(line)
    }

    private static func add(
        _ recipe: Recipe,
        quantityMultiplier: Double,
        to plan: WeekPlan,
        in modelContext: ModelContext
    ) {
        let meal = PlannedMeal(
            quantityMultiplier: quantityMultiplier,
            sortOrder: plan.plannedMeals?.count ?? 0,
            recipe: recipe
        )
        plan.plannedMeals = (plan.plannedMeals ?? []) + [meal]
        modelContext.insert(meal)
    }
}
