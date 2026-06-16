//
//  IngredientEnrichmentRunner.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation
import SwiftData

@MainActor
enum IngredientEnrichmentRunner {
    static func enrichPendingIngredients(
        in modelContext: ModelContext
    ) async {
        let ingredients = (try? modelContext.fetch(
            FetchDescriptor<Ingredient>(sortBy: [SortDescriptor(\.name)])
        )) ?? []
        let pendingIngredients = ingredients.filter {
            $0.category == nil
        }

        await enrichIngredients(pendingIngredients, in: modelContext)
    }

    static func enrichCreatedIngredients(
        _ ingredients: [Ingredient],
        in modelContext: ModelContext
    ) async {
        await enrichIngredients(ingredients, in: modelContext)
    }

    private static func enrichIngredients(
        _ ingredients: [Ingredient],
        in modelContext: ModelContext
    ) async {
        guard !ingredients.isEmpty else { return }

        for ingredient in ingredients {
            await enrichCreatedIngredient(ingredient, in: modelContext)
        }
    }

    private static func enrichCreatedIngredient(
        _ ingredient: Ingredient,
        in modelContext: ModelContext
    ) async {
        if ingredient.category == nil {
            let categories = (try? modelContext.fetch(FetchDescriptor<IngredientCategory>())) ?? []
            ingredient.category = await IngredientCategorySuggestionService.suggestedCategory(
                for: ingredient.name,
                from: categories
            )
            try? modelContext.save()
        }
    }
}
