//
//  PreviewData.swift
//  Food Basket
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
        container = PreviewModelContainer.make()
        let modelContext = container.mainContext

        let produce = IngredientCategory(name: "Produce")
        let meat = IngredientCategory(name: "Meat")
        let pantry = IngredientCategory(name: "Pantry")
        let each = MeasurementUnit(name: "Each", symbol: "each")
        let gram = MeasurementUnit(name: "Gram", symbol: "g")
        let lunch = MealType(name: "Lunch")
        let dinner = MealType(name: "Dinner")

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
            serves: 4,
            mealType: dinner
        )
        Self.add(chicken, quantity: 500, to: lemonChicken, in: modelContext)
        Self.add(lemon, quantity: 1, to: lemonChicken, in: modelContext)
        Self.add(broccoli, quantity: 1, to: lemonChicken, in: modelContext)
        Self.add(rice, quantity: 300, to: lemonChicken, in: modelContext)

        let broccoliRice = Recipe(
            name: "Broccoli Rice Bowl",
            method: "Steam the broccoli and serve over rice with your preferred dressing.",
            cookingTimeMinutes: 25,
            serves: 2,
            mealType: lunch
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
            lunch,
            dinner,
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
            weekPlan: plan,
            recipe: recipe
        )
        plan.plannedMeals = (plan.plannedMeals ?? []) + [meal]
        modelContext.insert(meal)

        let existingPortions = (try? modelContext.fetch(FetchDescriptor<PlannedMealPortion>())) ?? []
        let firstSortOrder = (
            existingPortions
                .filter { $0.weekPlan?.id == plan.id && $0.dayOffset == 0 }
                .map(\.sortOrder)
                .max() ?? -1
        ) + 1

        for index in 0..<PlannedMealPortion.portionCount(for: meal) {
            modelContext.insert(
                PlannedMealPortion(
                    dayOffset: 0,
                    sortOrder: firstSortOrder + index,
                    weekPlan: plan,
                    plannedMeal: meal
                )
            )
        }
    }
}

struct EmptyPreviewData {
    let container = PreviewModelContainer.make()
}

private enum PreviewModelContainer {
    static func make() -> ModelContainer {
        let schema = FoodBasketDataSchema.current
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }
}
