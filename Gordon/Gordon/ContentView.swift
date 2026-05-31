//
//  ContentView.swift
//  Gordon
//
//  Created by Logan Janssen | Codify on 31/5/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }

            WeekPlanView()
                .tabItem {
                    Label("This Week", systemImage: "calendar")
                }

            ShoppingListView()
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }

            IngredientsView()
                .tabItem {
                    Label("Ingredients", systemImage: "carrot")
                }
        }
        .task {
            SeedData.ensureDefaults(in: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Recipe.self,
                RecipeIngredient.self,
                Ingredient.self,
                IngredientCategory.self,
                MeasurementUnit.self,
                WeekPlan.self,
                PlannedMeal.self,
            ],
            inMemory: true
        )
}
