//
//  WeekPlanView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

struct WeekPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]
    @State private var showingAddMeal = false

    private let weekStarting = Calendar.current.startOfWeek(containing: Date())

    private var currentPlan: WeekPlan? {
        plans.first {
            Calendar.current.isDate($0.weekStarting, inSameDayAs: weekStarting)
        }
    }

    private var plannedMeals: [PlannedMeal] {
        (currentPlan?.plannedMeals ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if plannedMeals.isEmpty {
                        Text("Add recipes you want to cook this week.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(plannedMeals) { plannedMeal in
                        HStack {
                            Text(plannedMeal.recipe?.name ?? "Deleted recipe")
                            Spacer()
                            Text(plannedMeal.formattedMultiplier)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteMeals)
                } header: {
                    Text("Week of \(weekStarting.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .listStyle(.plain)
            .navigationTitle("This Week")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddMeal = true
                    } label: {
                        Label("Add Meal", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                NavigationStack {
                    AddPlannedMealView(weekStarting: weekStarting)
                }
            }
            .task {
                _ = SeedData.weekPlan(
                    starting: weekStarting,
                    existing: plans,
                    in: modelContext
                )
            }
        }
    }

    private func deleteMeals(at offsets: IndexSet) {
        let deletedMeals = offsets.map { plannedMeals[$0] }

        for meal in deletedMeals {
            modelContext.delete(meal)
        }
    }
}

struct AddPlannedMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]

    let weekStarting: Date
    @State private var selectedRecipeID: UUID?
    @State private var quantityMultiplier = 1.0

    var body: some View {
        Form {
            Section("Meal") {
                if recipes.isEmpty {
                    Text("Create a recipe before adding a meal.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Recipe", selection: $selectedRecipeID) {
                        Text("Select a recipe").tag(nil as UUID?)

                        ForEach(recipes) { recipe in
                            Text(recipe.name).tag(recipe.id as UUID?)
                        }
                    }

                    TextField("Number of batches", value: $quantityMultiplier, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .navigationTitle("Add Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addMeal()
                }
                .disabled(selectedRecipe == nil || quantityMultiplier <= 0)
            }
        }
        .task {
            if selectedRecipeID == nil {
                selectedRecipeID = recipes.first?.id
            }
        }
    }

    private var selectedRecipe: Recipe? {
        recipes.first { $0.id == selectedRecipeID }
    }

    private func addMeal() {
        guard let selectedRecipe else { return }

        let plan = SeedData.weekPlan(
            starting: weekStarting,
            existing: plans,
            in: modelContext
        )
        let meal = PlannedMeal(
            quantityMultiplier: quantityMultiplier,
            sortOrder: plan.plannedMeals.count,
            recipe: selectedRecipe
        )
        plan.plannedMeals.append(meal)
        modelContext.insert(meal)
        dismiss()
    }
}

private extension PlannedMeal {
    var formattedMultiplier: String {
        let quantity = quantityMultiplier.formatted(.number.precision(.fractionLength(0...2)))
        return "\(quantity)x"
    }
}
