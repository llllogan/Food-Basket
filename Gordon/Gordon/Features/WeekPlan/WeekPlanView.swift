//
//  WeekPlanView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import AppIntents
import SwiftData
import SwiftUI

struct WeekPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]
    @State private var showingAddMeal = false
    @State private var showingIngredients = false
    @State private var remindersExporter = RemindersExporter()
    @State private var reminderLists: [ReminderListOption] = []
    @State private var showingReminderListPicker = false
    @State private var isUpdatingReminders = false
    @State private var exportAlert: ReminderExportAlert?
    @AppStorage(ReminderListDefaults.idKey) private var lastRemindersListID = ""
    @AppStorage(ReminderListDefaults.nameKey) private var lastRemindersListName = ""
    @AppStorage("isDinnerPlanSiriTipVisible") private var isDinnerPlanSiriTipVisible = true

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

    private var rememberedReminderList: ReminderListOption? {
        guard !lastRemindersListID.isEmpty, !lastRemindersListName.isEmpty else {
            return nil
        }

        return ReminderListOption(
            id: lastRemindersListID,
            title: lastRemindersListName,
            sourceTitle: ""
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if !showingIngredients {
                    SiriTipView(
                        intent: GetDinnerPlanIntent(),
                        isVisible: $isDinnerPlanSiriTipVisible
                    )
                    .listRowSeparator(.hidden)
                }

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
                            if let recipe = plannedMeal.recipe {
                                NavigationLink {
                                    RecipeDetailView(recipe: recipe)
                                } label: {
                                    plannedMealRow(for: plannedMeal)
                                }
                            } else {
                                plannedMealRow(for: plannedMeal)
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
                    Menu {

                        Button {
                            prepareReminderListSelection()
                        } label: {
                            Label("Add to Reminders", systemImage: "list.bullet")
                        }
                        .disabled(shoppingListLines.isEmpty)

                        if let rememberedReminderList {

                            Divider()

                            Button {
                                addReminders(to: rememberedReminderList)
                            } label: {
                                Label("Add to \(rememberedReminderList.title)", systemImage: "plus")
                            }
                            .disabled(shoppingListLines.isEmpty)

                            Button(role: .destructive) {
                                clearReminders(from: rememberedReminderList)
                            } label: {
                                Text("Clear \(rememberedReminderList.title)")
                                Text("remove items automatically added")
                                Image(systemName: "trash")
                            }
                        }


                    } label: {
                        if isUpdatingReminders {
                            ProgressView()
                        } else {
                            Label("Update Reminders", systemImage: "checklist")
                        }
                    }
                    .disabled(
                        isUpdatingReminders ||
                        (rememberedReminderList == nil && shoppingListLines.isEmpty)
                    )

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
                        addReminders(to: list)
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

    private func plannedMealRow(for plannedMeal: PlannedMeal) -> some View {
        HStack(spacing: 12) {
            RecipeThumbnailView(photoData: plannedMeal.recipe?.photoData)

            Text(plannedMeal.recipe?.name ?? "Deleted recipe")
            Spacer()
            Text(plannedMeal.formattedMultiplier)
                .foregroundStyle(.secondary)
        }
    }

    private func prepareReminderListSelection() {
        isUpdatingReminders = true

        Task { @MainActor in
            defer {
                isUpdatingReminders = false
            }

            do {
                reminderLists = try await remindersExporter.availableLists()

                guard !reminderLists.isEmpty else {
                    throw RemindersExportError.noWritableLists
                }

                showingReminderListPicker = true
            } catch {
                showRemindersError(error)
            }
        }
    }

    private func addReminders(to list: ReminderListOption) {
        isUpdatingReminders = true

        Task { @MainActor in
            defer {
                isUpdatingReminders = false
            }

            do {
                try await remindersExporter.export(shoppingListLines, to: list)
                remember(list)
                exportAlert = ReminderExportAlert(
                    title: "Shopping List Added",
                    message: "\(shoppingListLines.count) items were added to \(list.title)."
                )
            } catch {
                showRemindersError(error, for: list)
            }
        }
    }

    private func clearReminders(from list: ReminderListOption) {
        isUpdatingReminders = true

        Task { @MainActor in
            defer {
                isUpdatingReminders = false
            }

            do {
                let removedCount = try await remindersExporter.clearAutomaticallyAddedReminders(
                    from: list
                )
                exportAlert = ReminderExportAlert(
                    title: "Shopping List Cleared",
                    message: "\(removedCount) automatically added items were removed from \(list.title)."
                )
            } catch {
                showRemindersError(error, for: list)
            }
        }
    }

    private func remember(_ list: ReminderListOption) {
        lastRemindersListID = list.id
        lastRemindersListName = list.title
    }

    private func forgetRememberedList(ifMatching list: ReminderListOption) {
        guard list.id == lastRemindersListID else { return }
        lastRemindersListID = ""
        lastRemindersListName = ""
    }

    private func showRemindersError(_ error: Error, for list: ReminderListOption? = nil) {
        if let list,
           let remindersError = error as? RemindersExportError,
           remindersError == .listUnavailable {
            forgetRememberedList(ifMatching: list)
        }

        exportAlert = ReminderExportAlert(
            title: "Unable to Update Reminders",
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
