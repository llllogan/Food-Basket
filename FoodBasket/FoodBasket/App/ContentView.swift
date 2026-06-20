//
//  ContentView.swift
//  Food Basket
//
//  Created by Logan Janssen | Codify on 31/5/2026.
//

import CoreSpotlight
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var selectedTab = FoodBasketTab.recipes
    @State private var selectedWeekPlanMode = WeekPlanDisplayMode.list
    @State private var highlightedThisWeekPortionIDs: Set<UUID> = []
    @State private var selectedRecipeID: UUID?

    init() {}

    init(
        selectedTab: FoodBasketTab,
        selectedWeekPlanMode: WeekPlanDisplayMode = .list,
        selectedRecipeID: UUID? = nil
    ) {
        _selectedTab = State(initialValue: selectedTab)
        _selectedWeekPlanMode = State(initialValue: selectedWeekPlanMode)
        _selectedRecipeID = State(initialValue: selectedRecipeID)
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

            WeekPlanSettingsView(
                onOpenThisWeekCalendar: openThisWeekCalendar
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(FoodBasketTab.settings)
        }
        .fontDesign(.rounded)
        .dismissKeyboardOnTapOutsideTextInputs()
        .onOpenURL(perform: openDeepLink)
        .onContinueUserActivity(CSSearchableItemActionType, perform: openSpotlightResult)
        .task {
            SeedData.ensureDefaults(in: modelContext)
            let removedDuplicateMealTypeCount = (try? FoodBasketDataMaintenance.deduplicateMealTypes(
                in: modelContext
            )) ?? 0
            let removedDuplicateMeasurementUnitCount = (try? FoodBasketDataMaintenance.deduplicateMeasurementUnits(
                in: modelContext
            )) ?? 0
            if removedDuplicateMealTypeCount + removedDuplicateMeasurementUnitCount > 0,
               (try? FoodBasketPlanSnapshotStore.refresh(in: modelContext)) != nil {
                FoodBasketWidgetTimelineReloader.reloadTimelines()
            }
            await WeekPlanAutomation.runLaunchMaintenance(in: modelContext)
            RecipeSpotlightIndexer.scheduleReindexing(recipes: recipes)
        }
        .onChange(of: recipeSpotlightSnapshots) { _, _ in
            RecipeSpotlightIndexer.scheduleReindexing(recipes: recipes)
        }
    }

    private var recipeSpotlightSnapshots: [RecipeSpotlightSnapshot] {
        recipes.map(RecipeSpotlightSnapshot.init(recipe:))
    }

    private func openDeepLink(_ url: URL) {
        guard let deepLink = FoodBasketDeepLink(url: url) else { return }

        openDeepLink(deepLink)
    }

    private func openSpotlightResult(_ userActivity: NSUserActivity) {
        guard let searchableItemUniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let recipeID = RecipeSpotlightIndexer.recipeID(from: searchableItemUniqueIdentifier) else {
            return
        }

        openDeepLink(.recipe(recipeID))
    }

    private func openDeepLink(_ deepLink: FoodBasketDeepLink) {
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

    private func openThisWeekCalendar() {
        openThisWeekCalendar(highlightedPortionIDs: [])
    }
}

enum FoodBasketTab: Hashable {
    case recipes
    case weekPlan
    case ingredients
    case settings
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

#Preview("Empty Settings Tab") {
    let previewData = EmptyPreviewData()

    ContentView(selectedTab: .settings)
        .modelContainer(previewData.container)
}
