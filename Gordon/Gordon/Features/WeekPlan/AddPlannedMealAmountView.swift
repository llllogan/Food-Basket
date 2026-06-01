//
//  AddPlannedMealAmountView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct AddPlannedMealAmountView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]

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
            recipe: recipe
        )
        plan.plannedMeals = (plan.plannedMeals ?? []) + [meal]
        modelContext.insert(meal)
        onAdd()
    }
}
