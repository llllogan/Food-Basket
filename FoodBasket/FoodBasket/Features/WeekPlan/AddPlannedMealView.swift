//
//  AddPlannedMealView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct AddPlannedMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]

    let weekStarting: Date
    @State private var searchText = ""

    private var filteredRecipes: [Recipe] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return recipes }

        return recipes.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        List {
            Section("Recipes") {
                if recipes.isEmpty {
                    Text("Create a recipe before adding a meal.")
                        .foregroundStyle(.secondary)
                } else if filteredRecipes.isEmpty {
                    Text("No recipes found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredRecipes) { recipe in
                        Button {
                            addMeal(recipe)
                        } label: {
                            HStack(spacing: 12) {
                                RecipeThumbnailView(photoData: recipe.photoData)

                                Text(recipe.name)
                                    .foregroundStyle(Color(.label))

                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Meal")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search recipes"
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func addMeal(_ recipe: Recipe) {
        let plan = SeedData.weekPlan(
            starting: weekStarting,
            existing: plans,
            in: modelContext
        )
        let meal = PlannedMeal(
            quantityMultiplier: onePortionMultiplier(for: recipe),
            sortOrder: plan.plannedMeals?.count ?? 0,
            weekPlan: plan,
            recipe: recipe
        )
        plan.plannedMeals = (plan.plannedMeals ?? []) + [meal]
        modelContext.insert(meal)

        let firstSortOrder = nextMondayPortionSortOrder(for: plan)
        modelContext.insert(
            PlannedMealPortion(
                dayOffset: 0,
                sortOrder: firstSortOrder,
                weekPlan: plan,
                plannedMeal: meal
            )
        )

        try? modelContext.save()
        _ = try? FoodBasketPlanSnapshotStore.refresh(in: modelContext)
        FoodBasketWidgetTimelineReloader.reloadTimelines()
        dismiss()
    }

    private func onePortionMultiplier(for recipe: Recipe) -> Double {
        1.0 / Double(max(recipe.serves, 1))
    }

    private func nextMondayPortionSortOrder(for plan: WeekPlan) -> Int {
        let portions = (try? modelContext.fetch(FetchDescriptor<PlannedMealPortion>())) ?? []
        let maxSortOrder = portions
            .filter { $0.weekPlan?.id == plan.id && $0.dayOffset == 0 }
            .map(\.sortOrder)
            .max()

        return (maxSortOrder ?? -1) + 1
    }
}

#Preview("Add Meal") {
    let previewData = PreviewData()

    NavigationStack {
        AddPlannedMealView(
            weekStarting: Calendar.current.startOfWeek(containing: Date())
        )
    }
    .modelContainer(previewData.container)
}
