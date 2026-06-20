//
//  WeekPlanSettingsView.swift
//  Food Basket
//
//  Created by Codex on 6/6/2026.
//

import SwiftData
import SwiftUI

struct WeekPlanSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealType.name) private var mealTypes: [MealType]
    private let onOpenThisWeekCalendar: () -> Void

    @State private var calendarExporter = CalendarEventExporter()
    @State private var syncCalendarLists: [CalendarListOption] = []
    @State private var showingSyncCalendarPicker = false
    @State private var isUpdatingCalendar = false
    @State private var exportAlert: ReminderExportAlert?
    @State private var ingredientImagePromptDraft = IngredientImagePromptDefaults.savedTemplate
    @State private var ingredientImagePromptBeforeEditing: String?
    @State private var recipeImagePromptDraft = RecipeImagePromptDefaults.savedTemplate
    @State private var recipeImagePromptBeforeEditing: String?
    @FocusState private var isEditingIngredientImagePrompt
    @FocusState private var isEditingRecipeImagePrompt

    @AppStorage(CalendarListDefaults.idKey) private var lastCalendarID = ""
    @AppStorage(CalendarListDefaults.nameKey) private var lastCalendarName = ""
    @AppStorage(CalendarListDefaults.sourceTitleKey) private var lastCalendarSourceTitle = ""
    @AppStorage(CalendarSyncDefaults.isEnabledKey) private var syncToICal = false
    @AppStorage(CalendarSyncDefaults.calendarIDKey) private var syncCalendarID = ""
    @AppStorage(CalendarSyncDefaults.calendarNameKey) private var syncCalendarName = ""
    @AppStorage(CalendarSyncDefaults.calendarSourceTitleKey) private var syncCalendarSourceTitle = ""
    @AppStorage(WeekPlanAutomationDefaults.removeMealsAtNewWeekKey) private var removeMealsAtNewWeek = false
    @AppStorage(WeekPlanAutomationDefaults.weekStartDayKey) private var weekStartDay = WeekStartDay.monday.rawValue
    @AppStorage(WeekPlanCalendarFilterDefaults.excludedMealTypeIDsKey) private var excludedCalendarMealTypeIDsRaw = ""
    @AppStorage(WeekPlanCalendarFilterDefaults.excludeMealsWithoutMealTypeKey) private var excludeCalendarMealsWithoutMealType = false
    @AppStorage(ReminderListDefaults.idKey) private var lastRemindersListID = ""
    @AppStorage(ReminderListDefaults.nameKey) private var lastRemindersListName = ""
    @AppStorage(IngredientImagePromptDefaults.templateKey) private var ingredientImagePromptTemplate = IngredientImagePromptDefaults.defaultTemplate
    @AppStorage(RecipeImagePromptDefaults.templateKey) private var recipeImagePromptTemplate = RecipeImagePromptDefaults.defaultTemplate

    init(onOpenThisWeekCalendar: @escaping () -> Void = {}) {
        self.onOpenThisWeekCalendar = onOpenThisWeekCalendar
    }

    private var selectedSyncCalendar: CalendarListOption? {
        guard !syncCalendarID.isEmpty, !syncCalendarName.isEmpty else {
            return nil
        }

        return CalendarListOption(
            id: syncCalendarID,
            title: syncCalendarName,
            sourceTitle: syncCalendarSourceTitle
        )
    }

    private var hasIngredientImagePromptChanges: Bool {
        ingredientImagePromptDraft != ingredientImagePromptTemplate
    }

    private var hasRecipeImagePromptChanges: Bool {
        recipeImagePromptDraft != recipeImagePromptTemplate
    }

    private var hasImagePromptChanges: Bool {
        hasIngredientImagePromptChanges || hasRecipeImagePromptChanges
    }

    private var canSaveIngredientImagePrompt: Bool {
        IngredientImagePromptDefaults.isValid(ingredientImagePromptDraft)
    }

    private var canSaveRecipeImagePrompt: Bool {
        RecipeImagePromptDefaults.isValid(recipeImagePromptDraft)
    }

    private var canSaveImagePrompts: Bool {
        (!hasIngredientImagePromptChanges || canSaveIngredientImagePrompt)
            && (!hasRecipeImagePromptChanges || canSaveRecipeImagePrompt)
    }

    private var automaticCalendarSyncKey: String {
        [
            syncToICal ? "sync-on" : "sync-off",
            syncCalendarID,
            syncCalendarSourceTitle,
            removeMealsAtNewWeek ? "cleanup-on" : "cleanup-off",
            "\(weekStartDay)",
        ].joined(separator: "#")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("This Week Settings") {
                    NavigationLink {
                        ThisWeekSettingsGroup(
                            mealTypes: mealTypes,
                            removeMealsAtNewWeek: $removeMealsAtNewWeek,
                            weekStartDay: $weekStartDay,
                            excludedCalendarMealTypeIDsRaw: $excludedCalendarMealTypeIDsRaw,
                            excludeCalendarMealsWithoutMealType: $excludeCalendarMealsWithoutMealType,
                            onOpenThisWeekCalendar: onOpenThisWeekCalendar
                        )
                    } label: {
                        Label {
                            Text("View and weekly cleanup")
                        } icon: {
                            Image(systemName: "refrigerator")
                                .font(.subheadline)
                        }
                    }
                }

                Section("Image Generation") {
                    NavigationLink {
                        ImageGenerationSettingsGroup(
                            ingredientImagePromptDraft: $ingredientImagePromptDraft,
                            ingredientImagePromptTemplate: $ingredientImagePromptTemplate,
                            recipeImagePromptDraft: $recipeImagePromptDraft,
                            recipeImagePromptTemplate: $recipeImagePromptTemplate,
                            isEditingIngredientImagePrompt: $isEditingIngredientImagePrompt,
                            isEditingRecipeImagePrompt: $isEditingRecipeImagePrompt,
                            hasImagePromptChanges: hasImagePromptChanges,
                            canSaveImagePrompts: canSaveImagePrompts,
                            onSaveImagePrompts: saveImagePrompts,
                            onCancelImagePromptEditing: cancelImagePromptEditing,
                            onResetIngredientImagePrompt: resetIngredientImagePrompt,
                            onResetRecipeImagePrompt: resetRecipeImagePrompt
                        )
                    } label: {
                        Label {
                            Text("Configure prompts")
                        } icon: {
                            Image("custom.photo.badge.sparkles")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                                .padding(.bottom, -4)
                        }
                    }
                }

                Section("Calendar and Reminders Syncing") {
                    NavigationLink {
                        CalendarRemindersSyncSettingsGroup(
                            syncToICal: $syncToICal,
                            syncCalendarName: syncCalendarName,
                            isUpdatingCalendar: isUpdatingCalendar,
                            lastRemindersListID: lastRemindersListID,
                            lastRemindersListName: lastRemindersListName,
                            lastCalendarID: lastCalendarID,
                            lastCalendarName: lastCalendarName,
                            onChooseSyncCalendar: prepareSyncCalendarSelection,
                            onClearDefaultRemindersList: clearDefaultRemindersList,
                            onClearDefaultCalendar: clearDefaultCalendar
                        )
                    } label: {
                        Label {
                            Text("Update sync settings")
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .center) {
                        Text("Made with greate care")
                        Text("by Logan")
                        Text("for you")
                        Text("🥑")
                            .padding(.top, 4)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                }
                .listRowBackground(Color(.clear))
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingSyncCalendarPicker) {
                NavigationStack {
                    ExternalListPickerView(
                        isCalendar: true,
                        options: syncCalendarLists
                    ) { calendar in
                        rememberSyncCalendar(calendar)
                        Task {
                            await performCalendarAutomation()
                        }
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
            .task(id: automaticCalendarSyncKey) {
                await performCalendarAutomation()
            }
            .onAppear {
                ingredientImagePromptDraft = ingredientImagePromptTemplate
                recipeImagePromptDraft = recipeImagePromptTemplate
            }
            .onChange(of: isEditingIngredientImagePrompt) { _, isEditing in
                if isEditing {
                    ingredientImagePromptBeforeEditing = ingredientImagePromptDraft
                } else {
                    ingredientImagePromptBeforeEditing = nil
                }
            }
            .onChange(of: isEditingRecipeImagePrompt) { _, isEditing in
                if isEditing {
                    recipeImagePromptBeforeEditing = recipeImagePromptDraft
                } else {
                    recipeImagePromptBeforeEditing = nil
                }
            }
        }
    }

    private func prepareSyncCalendarSelection() {
        isUpdatingCalendar = true

        Task { @MainActor in
            defer {
                isUpdatingCalendar = false
            }

            do {
                syncCalendarLists = try await calendarExporter.availableCalendars()

                guard !syncCalendarLists.isEmpty else {
                    throw CalendarExportError.noWritableCalendars
                }

                showingSyncCalendarPicker = true
            } catch {
                showCalendarError(error)
            }
        }
    }

    private func rememberSyncCalendar(_ calendar: CalendarListOption) {
        syncCalendarID = calendar.id
        syncCalendarName = calendar.title
        syncCalendarSourceTitle = calendar.sourceTitle
    }

    private func clearDefaultCalendar() {
        lastCalendarID = ""
        lastCalendarName = ""
        lastCalendarSourceTitle = ""
    }

    private func clearDefaultRemindersList() {
        lastRemindersListID = ""
        lastRemindersListName = ""
    }

    private func saveImagePrompts() {
        guard canSaveImagePrompts else { return }

        if hasIngredientImagePromptChanges {
            ingredientImagePromptTemplate = ingredientImagePromptDraft
            ingredientImagePromptBeforeEditing = ingredientImagePromptDraft
        }

        if hasRecipeImagePromptChanges {
            recipeImagePromptTemplate = recipeImagePromptDraft
            recipeImagePromptBeforeEditing = recipeImagePromptDraft
        }
    }

    private func cancelImagePromptEditing() {
        if isEditingIngredientImagePrompt {
            ingredientImagePromptDraft = ingredientImagePromptBeforeEditing ?? ingredientImagePromptTemplate
            isEditingIngredientImagePrompt = false
        }

        if isEditingRecipeImagePrompt {
            recipeImagePromptDraft = recipeImagePromptBeforeEditing ?? recipeImagePromptTemplate
            isEditingRecipeImagePrompt = false
        }
    }

    private func resetIngredientImagePrompt() {
        ingredientImagePromptDraft = IngredientImagePromptDefaults.defaultTemplate
        ingredientImagePromptTemplate = IngredientImagePromptDefaults.defaultTemplate
        ingredientImagePromptBeforeEditing = IngredientImagePromptDefaults.defaultTemplate
    }

    private func resetRecipeImagePrompt() {
        recipeImagePromptDraft = RecipeImagePromptDefaults.defaultTemplate
        recipeImagePromptTemplate = RecipeImagePromptDefaults.defaultTemplate
        recipeImagePromptBeforeEditing = RecipeImagePromptDefaults.defaultTemplate
    }

    private func showCalendarError(_ error: Error) {
        exportAlert = ReminderExportAlert(
            title: "Unable to Update Calendar",
            message: error.localizedDescription
        )
    }

    private func performCalendarAutomation() async {
        do {
            _ = try WeekPlanAutomation.removeMealsAtStartOfNewWeekIfNeeded(in: modelContext)

            guard syncToICal,
                  let selectedSyncCalendar else {
                return
            }

            _ = try await WeekPlanAutomation.syncCurrentWeekCalendar(
                in: modelContext,
                to: selectedSyncCalendar
            )
        } catch {
            return
        }
    }
}

#Preview("Settings") {
    let previewData = PreviewData()

    WeekPlanSettingsView()
        .modelContainer(previewData.container)
}
