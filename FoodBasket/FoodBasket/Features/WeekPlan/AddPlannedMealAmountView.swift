//
//  AddPlannedMealAmountView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct AddPlannedMealAmountView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]
    @Query(sort: \PlannedMealPortion.sortOrder) private var mealPortions: [PlannedMealPortion]

    let weekStarting: Date
    let recipe: Recipe
    let onAdd: () -> Void
    @State private var quantityMultiplier = 1.0

    var body: some View {
        Form {
            Section("Meal") {
                LabeledContent("Recipe", value: recipe.name)
            }

            Section("Amount") {
                TextField("Number of batches", value: $quantityMultiplier, format: .number)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Select Amount")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addMeal()
                }
                .disabled(quantityMultiplier <= 0)
            }
        }
    }

    private func addMeal() {
        let plan = SeedData.weekPlan(
            starting: weekStarting,
            existing: plans,
            in: modelContext
        )
        let meal = PlannedMeal(
            quantityMultiplier: quantityMultiplier,
            sortOrder: plan.plannedMeals?.count ?? 0,
            weekPlan: plan,
            recipe: recipe
        )
        plan.plannedMeals = (plan.plannedMeals ?? []) + [meal]
        modelContext.insert(meal)

        let firstSortOrder = nextMondayPortionSortOrder(for: plan)
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

        onAdd()
    }

    private func nextMondayPortionSortOrder(for plan: WeekPlan) -> Int {
        let maxSortOrder = mealPortions
            .filter { $0.weekPlan?.id == plan.id && $0.dayOffset == 0 }
            .map(\.sortOrder)
            .max()

        return (maxSortOrder ?? -1) + 1
    }
}
