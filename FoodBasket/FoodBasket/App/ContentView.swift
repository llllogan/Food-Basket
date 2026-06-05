//
//  ContentView.swift
//  Food Basket
//
//  Created by Logan Janssen | Codify on 31/5/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = FoodBasketTab.recipes
    @State private var selectedRecipeID: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipesView(selectedRecipeID: $selectedRecipeID)
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
                .tag(FoodBasketTab.recipes)

            WeekPlanView()
                .tabItem {
                    Label("This Week", systemImage: "refrigerator")
                }
                .tag(FoodBasketTab.weekPlan)

            IngredientsView()
                .tabItem {
                    Label("Ingredients", systemImage: "carrot")
                }
                .tag(FoodBasketTab.ingredients)
        }
        .dismissKeyboardOnTapOutsideTextInputs()
        .onOpenURL(perform: openDeepLink)
        .task {
            SeedData.ensureDefaults(in: modelContext)
        }
    }

    private func openDeepLink(_ url: URL) {
        guard let deepLink = FoodBasketDeepLink(url: url) else { return }

        switch deepLink {
        case .recipe(let recipeID):
            selectedTab = .recipes
            selectedRecipeID = recipeID
        }
    }
}

private enum FoodBasketTab: Hashable {
    case recipes
    case weekPlan
    case ingredients
}

#Preview("App") {
    let previewData = PreviewData()

    ContentView()
        .modelContainer(previewData.container)
}
