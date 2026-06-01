//
//  GordonModelContainer.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import SwiftData

@MainActor
enum GordonModelContainer {
    static let shared = make()

    static func make(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        let schema = Schema([
            Recipe.self,
            RecipeIngredient.self,
            Ingredient.self,
            IngredientCategory.self,
            MeasurementUnit.self,
            WeekPlan.self,
            PlannedMeal.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
