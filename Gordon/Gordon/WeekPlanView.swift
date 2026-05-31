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
    @State private var showingIngredients = false
    @State private var remindersExporter = RemindersExporter()
    @State private var reminderLists: [ReminderListOption] = []
    @State private var showingReminderListPicker = false
    @State private var isPreparingReminderExport = false
    @State private var exportAlert: ReminderExportAlert?

    private let weekStarting = Calendar.current.startOfWeek(containing: Date())

    init(showingIngredients: Bool = false) {
        _showingIngredients = State(initialValue: showingIngredients)
    }

    private var currentPlan: WeekPlan? {
        plans.first {
            Calendar.current.isDate($0.weekStarting, inSameDayAs: weekStarting)
        }
    }

    private var plannedMeals: [PlannedMeal] {
        (currentPlan?.plannedMeals ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var shoppingListLines: [ShoppingListLine] {
        ShoppingListLine.makeLines(for: currentPlan)
    }

    private var shoppingListCategories: [String] {
        Set(shoppingListLines.map(\.categoryName)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if showingIngredients {
                    if shoppingListLines.isEmpty {
                        Text("Add meals to this week to build your shopping list.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(shoppingListCategories, id: \.self) { category in
                        Section(category) {
                            ForEach(shoppingListLines.filter { $0.categoryName == category }) { line in
                                HStack(spacing: 12) {
                                    IngredientThumbnailView(photoData: line.photoData)

                                    Text(line.ingredientName)
                                    Spacer()
                                    Text(line.formattedAmount)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        if plannedMeals.isEmpty {
                            Text("Add recipes you want to cook this week.")
                                .foregroundStyle(.secondary)
                        }

                        ForEach(plannedMeals) { plannedMeal in
                            HStack(spacing: 12) {
                                RecipeThumbnailView(photoData: plannedMeal.recipe?.photoData)

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
            }
            .listStyle(.plain)
            .navigationTitle("This Week")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingIngredients.toggle()
                    } label: {
                        Label(
                            showingIngredients ? "Show Meals" : "Show Shopping List",
                            systemImage: showingIngredients ? "refrigerator" : "cart"
                        )
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        prepareReminderExport()
                    } label: {
                        if isPreparingReminderExport {
                            ProgressView()
                        } else {
                            Label("Add to Reminders List", systemImage: "checklist")
                        }
                    }
                    .disabled(shoppingListLines.isEmpty || isPreparingReminderExport)

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
            .sheet(isPresented: $showingReminderListPicker) {
                NavigationStack {
                    ReminderListPickerView(lists: reminderLists) { list in
                        exportReminders(to: list)
                    }
                }
            }
            .alert(item: $exportAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
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

    private func prepareReminderExport() {
        isPreparingReminderExport = true

        Task { @MainActor in
            defer {
                isPreparingReminderExport = false
            }

            do {
                reminderLists = try await remindersExporter.availableLists()

                guard !reminderLists.isEmpty else {
                    throw RemindersExportError.noWritableLists
                }

                showingReminderListPicker = true
            } catch {
                showExportError(error)
            }
        }
    }

    private func exportReminders(to list: ReminderListOption) {
        do {
            try remindersExporter.export(shoppingListLines, to: list)
            exportAlert = ReminderExportAlert(
                title: "Shopping List Exported",
                message: "\(shoppingListLines.count) items were added to \(list.title)."
            )
        } catch {
            showExportError(error)
        }
    }

    private func showExportError(_ error: Error) {
        exportAlert = ReminderExportAlert(
            title: "Unable to Export",
            message: error.localizedDescription
        )
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

#Preview("This Week") {
    let previewData = PreviewData()

    WeekPlanView()
        .modelContainer(previewData.container)
}

#Preview("This Week Ingredients") {
    let previewData = PreviewData()

    WeekPlanView(showingIngredients: true)
        .modelContainer(previewData.container)
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
