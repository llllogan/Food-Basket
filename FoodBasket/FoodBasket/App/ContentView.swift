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
    @State private var selectedWeekPlanMode = WeekPlanDisplayMode.list
    @State private var highlightedThisWeekPortionIDs: Set<UUID> = []
    @State private var selectedRecipeID: UUID?

    init() {}

    init(
        selectedTab: FoodBasketTab,
        selectedWeekPlanMode: WeekPlanDisplayMode = .list
    ) {
        _selectedTab = State(initialValue: selectedTab)
        _selectedWeekPlanMode = State(initialValue: selectedWeekPlanMode)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipesView(
                selectedRecipeID: $selectedRecipeID,
                onOpenThisWeekCalendar: openThisWeekCalendar
            )
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
                .tag(FoodBasketTab.recipes)

            WeekPlanView(
                selectedMode: $selectedWeekPlanMode,
                highlightedPortionIDs: $highlightedThisWeekPortionIDs
            )
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
        .fontDesign(.rounded)
        .dismissKeyboardOnTapOutsideTextInputs()
        .onOpenURL(perform: openDeepLink)
        .task {
            SeedData.ensureDefaults(in: modelContext)
            await WeekPlanAutomation.runLaunchMaintenance(in: modelContext)
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

    private func openThisWeekCalendar(highlightedPortionIDs: Set<UUID>) {
        highlightedThisWeekPortionIDs = highlightedPortionIDs
        selectedWeekPlanMode = .calendar
        selectedTab = .weekPlan
    }
}

enum FoodBasketTab: Hashable {
    case recipes
    case weekPlan
    case ingredients
}

#Preview("App") {
    let previewData = PreviewData()

    ContentView()
        .modelContainer(previewData.container)
}

#Preview("Empty Recipes Tab") {
    let previewData = EmptyPreviewData()

    ContentView(selectedTab: .recipes)
        .modelContainer(previewData.container)
}

#Preview("Empty This Week Tab") {
    let previewData = EmptyPreviewData()

    ContentView(selectedTab: .weekPlan)
        .modelContainer(previewData.container)
}

#Preview("Empty Ingredients Tab") {
    let previewData = EmptyPreviewData()

    ContentView(selectedTab: .ingredients)
        .modelContainer(previewData.container)
}
