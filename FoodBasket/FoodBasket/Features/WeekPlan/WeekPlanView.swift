//
//  WeekPlanView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI
import TipKit
import UIKit

struct WeekPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query(sort: [
        SortDescriptor(\PlannedMealPortion.dayOffset),
        SortDescriptor(\PlannedMealPortion.sortOrder),
    ]) private var mealPortions: [PlannedMealPortion]

    @State private var selectedMode: WeekPlanDisplayMode
    @State private var showingAddMeal = false
    @State private var calendarExporter = CalendarEventExporter()
    @State private var calendarLists: [CalendarListOption] = []
    @State private var showingCalendarListPicker = false
    @State private var syncCalendarLists: [CalendarListOption] = []
    @State private var showingSyncCalendarPicker = false
    @State private var isUpdatingCalendar = false
    @State private var remindersExporter = RemindersExporter()
    @State private var reminderLists: [ReminderListOption] = []
    @State private var showingReminderListPicker = false
    @State private var isUpdatingReminders = false
    @State private var isAddGroceriesTipPresented = false
    @State private var exportAlert: ReminderExportAlert?
    @AppStorage(CalendarListDefaults.idKey) private var lastCalendarID = ""
    @AppStorage(CalendarListDefaults.nameKey) private var lastCalendarName = ""
    @AppStorage(CalendarSyncDefaults.isEnabledKey) private var syncToICal = false
    @AppStorage(CalendarSyncDefaults.calendarIDKey) private var syncCalendarID = ""
    @AppStorage(CalendarSyncDefaults.calendarNameKey) private var syncCalendarName = ""
    @AppStorage(WeekPlanAutomationDefaults.removeMealsAtNewWeekKey) private var removeMealsAtNewWeek = false
    @AppStorage(WeekPlanAutomationDefaults.weekStartDayKey) private var weekStartDay = WeekStartDay.monday.rawValue
    @AppStorage(ReminderListDefaults.idKey) private var lastRemindersListID = ""
    @AppStorage(ReminderListDefaults.nameKey) private var lastRemindersListName = ""

    private let addGroceriesTip = AddGroceriesToRemindersTip()
    private let planWeekStarting = Calendar.current.startOfWeek(containing: Date())
    private let calendarWeekStarting = WeekPlanCalendar.mondayStart(containing: Date())

    init(showingIngredients: Bool = false) {
        _selectedMode = State(initialValue: showingIngredients ? .groceryList : .calendar)
    }

    private var currentPlan: WeekPlan? {
        plans.first {
            Calendar.current.isDate($0.weekStarting, inSameDayAs: planWeekStarting)
        }
    }

    private var plannedMeals: [PlannedMeal] {
        (currentPlan?.plannedMeals ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentPlanPortions: [PlannedMealPortion] {
        guard let currentPlan else { return [] }

        return mealPortions.filter { portion in
            portion.weekPlan?.id == currentPlan.id ||
            portion.plannedMeal?.weekPlan?.id == currentPlan.id
        }
    }

    private var portionSyncKey: String {
        plannedMeals
            .map {
                "\($0.id.uuidString):\($0.recipe?.serves ?? 0):\($0.quantityMultiplier)"
            }
            .joined(separator: "|")
    }

    private var shoppingListLines: [ShoppingListLine] {
        ShoppingListLine.makeLines(for: currentPlan)
    }

    private var calendarMealPortions: [PlannedMealPortion] {
        currentPlanPortions.filter {
            $0.plannedMeal?.recipe != nil
        }
    }

    private var mealDaySections: [WeekPlanMealDaySection] {
        let validPortions = currentPlanPortions.filter {
            (0..<WeekPlanCalendar.dayCount).contains($0.dayOffset) &&
            $0.plannedMeal != nil
        }
        let portionsByDay = Dictionary(grouping: validPortions, by: \.dayOffset)

        return (0..<WeekPlanCalendar.dayCount).compactMap { dayOffset in
            guard let dayPortions = portionsByDay[dayOffset] else { return nil }

            let rows = mealDayRows(from: dayPortions, dayOffset: dayOffset)
            guard !rows.isEmpty else { return nil }

            let date = Calendar.current.date(
                byAdding: .day,
                value: dayOffset,
                to: calendarWeekStarting
            ) ?? calendarWeekStarting

            return WeekPlanMealDaySection(
                dayOffset: dayOffset,
                date: date,
                rows: rows
            )
        }
    }

    private var shoppingListCategories: [String] {
        Set(shoppingListLines.map(\.categoryName)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private var ingredientsByID: [UUID: Ingredient] {
        Dictionary(uniqueKeysWithValues: ingredients.map { ($0.id, $0) })
    }

    private var rememberedCalendar: CalendarListOption? {
        guard !lastCalendarID.isEmpty, !lastCalendarName.isEmpty else {
            return nil
        }

        return CalendarListOption(
            id: lastCalendarID,
            title: lastCalendarName,
            sourceTitle: ""
        )
    }

    private var selectedSyncCalendar: CalendarListOption? {
        guard !syncCalendarID.isEmpty, !syncCalendarName.isEmpty else {
            return nil
        }

        return CalendarListOption(
            id: syncCalendarID,
            title: syncCalendarName,
            sourceTitle: ""
        )
    }

    private var automaticCalendarSyncKey: String {
        [
            syncToICal ? "sync-on" : "sync-off",
            syncCalendarID,
            removeMealsAtNewWeek ? "cleanup-on" : "cleanup-off",
            "\(weekStartDay)",
            currentPlanPortions
                .map {
                    "\($0.id.uuidString):\($0.dayOffset):\($0.sortOrder):\($0.plannedMeal?.id.uuidString ?? ""):\($0.plannedMeal?.recipe?.id.uuidString ?? "")"
                }
                .joined(separator: "|"),
        ].joined(separator: "#")
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
                selectedRows
            }
            .listStyle(.plain)
            .navigationTitle("This Week")
            .safeAreaInset(edge: .top) {
                modePicker
                    .padding(.horizontal)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            prepareCalendarSelection()
                        } label: {
                            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        }
                        .disabled(calendarMealPortions.isEmpty)

                        if let rememberedCalendar {
                            Divider()

                            Button {
                                addCalendarEvents(to: rememberedCalendar)
                            } label: {
                                Text("Add to \(rememberedCalendar.title)")
                                Text("recently used calendar")
                                Image(systemName: "plus")
                            }
                            .disabled(calendarMealPortions.isEmpty)

                            Button(role: .destructive) {
                                clearCalendarEvents(from: rememberedCalendar)
                            } label: {
                                Text("Clear \(rememberedCalendar.title)")
                                Text("remove this week's Food Basket events")
                                Image(systemName: "trash")
                            }
                        }
                    } label: {
                        if isUpdatingCalendar {
                            ProgressView()
                        } else {
                            Label("Update Calendar", systemImage: "calendar.badge.plus")
                        }
                    }
                    .disabled(isUpdatingCalendar || syncToICal)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
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
                                Text("Add to \(rememberedReminderList.title)")
                                Text("recently used list")
                                Image(systemName: "plus")
                            }
                            .disabled(shoppingListLines.isEmpty)

                            Button(role: .destructive) {
                                clearReminders(from: rememberedReminderList)
                            } label: {
                                Text("Clear \(rememberedReminderList.title)")
                                Text("remove Food Basket items")
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
                        isUpdatingReminders
                    )
                    .popoverTip(
                        addGroceriesTip,
                        isPresented: $isAddGroceriesTipPresented,
                        arrowEdge: .top
                    )
                }
                
                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                
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
                    AddPlannedMealView(weekStarting: planWeekStarting)
                }
            }
            .sheet(isPresented: $showingCalendarListPicker) {
                NavigationStack {
                    CalendarListPickerView(calendars: calendarLists) { calendar in
                        addCalendarEvents(to: calendar)
                    }
                }
            }
            .sheet(isPresented: $showingSyncCalendarPicker) {
                NavigationStack {
                    CalendarListPickerView(calendars: syncCalendarLists) { calendar in
                        rememberSyncCalendar(calendar)
                        showingSyncCalendarPicker = false
                        Task {
                            await performCalendarAutomation()
                        }
                    }
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
            .onAppear {
                isAddGroceriesTipPresented = true
            }
            .task {
                let plan = SeedData.weekPlan(
                    starting: planWeekStarting,
                    existing: plans,
                    in: modelContext
                )
                syncCalendarPortions(for: plan)
                await performCalendarAutomation()
            }
            .task(id: portionSyncKey) {
                guard let currentPlan else { return }
                syncCalendarPortions(for: currentPlan)
            }
            .task(id: automaticCalendarSyncKey) {
                await performCalendarAutomation()
            }
        }
    }

    @ViewBuilder
    private var selectedRows: some View {
        switch selectedMode {
        case .calendar:
            calendarRow
            calendarSyncSettingsRows
            weeklyResetSettingsRows
        case .list:
            mealRows
        case .groceryList:
            groceryRows
        }
    }

    private var calendarRow: some View {
        WeekPlanCalendarView(
            weekStarting: calendarWeekStarting,
            portions: currentPlanPortions,
            movePortions: movePortions
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var calendarSyncSettingsRows: some View {
        Section {
            Toggle("Sync to iCal", isOn: $syncToICal)

            if syncToICal {
                Button {
                    prepareSyncCalendarSelection()
                } label: {
                    HStack {
                        Text("Calendar")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(syncCalendarName.isEmpty ? "Choose" : syncCalendarName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weeklyResetSettingsRows: some View {
        Section {
            Toggle("Remove meals at the start of a new week", isOn: $removeMealsAtNewWeek)

            if removeMealsAtNewWeek {
                Picker("Week starts", selection: $weekStartDay) {
                    ForEach(WeekStartDay.allCases) { day in
                        Text(day.title).tag(day.rawValue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mealRows: some View {
        if plannedMeals.isEmpty {
            Text("Add recipes you want to cook this week.")
                .foregroundStyle(.secondary)
        } else if mealDaySections.isEmpty {
            Text("Assign meal portions to days to build this list.")
                .foregroundStyle(.secondary)
        }

        ForEach(mealDaySections) { section in
            Section(section.title) {
                ForEach(section.rows) { row in
                    if let recipe = row.recipe {
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            plannedMealRow(for: row)
                        }
                    } else {
                        plannedMealRow(for: row)
                    }
                }
                .onDelete { offsets in
                    deleteMealRows(section.rows, at: offsets)
                }
            }
        }
    }

    private func mealDayRows(
        from portions: [PlannedMealPortion],
        dayOffset: Int
    ) -> [WeekPlanMealDayRow] {
        let sortedPortions = portions.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }

            return (lhs.plannedMeal?.sortOrder ?? 0) < (rhs.plannedMeal?.sortOrder ?? 0)
        }
        var rows: [WeekPlanMealDayRow] = []

        for (index, portion) in sortedPortions.enumerated() {
            guard let plannedMeal = portion.plannedMeal else { continue }

            let recipe = plannedMeal.recipe
            let rowKey = recipe
                .map { "recipe:\($0.id.uuidString)" } ??
                "meal:\(plannedMeal.id.uuidString)"

            if let existingIndex = rows.firstIndex(where: { $0.groupKey == rowKey }) {
                rows[existingIndex].portionCount += 1
                rows[existingIndex].plannedMealIDs.insert(plannedMeal.id)
            } else {
                rows.append(
                    WeekPlanMealDayRow(
                        id: "\(dayOffset)-\(rowKey)",
                        groupKey: rowKey,
                        recipe: recipe,
                        title: recipe?.name ?? "Deleted recipe",
                        portionCount: 1,
                        plannedMealIDs: [plannedMeal.id],
                        firstSortIndex: index
                    )
                )
            }
        }

        return rows.sorted {
            $0.firstSortIndex < $1.firstSortIndex
        }
    }

    private func plannedMealRow(for row: WeekPlanMealDayRow) -> some View {
        HStack(spacing: 12) {
            RecipeThumbnailView(photoData: row.recipe?.photoData)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                Text(row.portionCountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func deleteMealRows(_ rows: [WeekPlanMealDayRow], at offsets: IndexSet) {
        let mealIDs = Set(offsets.flatMap { rows[$0].plannedMealIDs })
        deleteMeals(withIDs: mealIDs)
    }

    private func deleteMeals(withIDs mealIDs: Set<UUID>) {
        for meal in plannedMeals where mealIDs.contains(meal.id) {
            for portion in currentPlanPortions where portion.plannedMeal?.id == meal.id {
                modelContext.delete(portion)
            }
            modelContext.delete(meal)
        }

        try? modelContext.save()
    }

    @ViewBuilder
    private var groceryRows: some View {
        if shoppingListLines.isEmpty {
            Text("Add meals to this week to build your shopping list.")
                .foregroundStyle(.secondary)
        }

        ForEach(shoppingListCategories, id: \.self) { category in
            Section(category) {
                ForEach(shoppingListLines.filter { $0.categoryName == category }) { line in
                    if let ingredient = ingredientsByID[line.ingredientID] {
                        NavigationLink {
                            IngredientDetailView(ingredient: ingredient)
                        } label: {
                            groceryRow(for: line)
                        }
                    } else {
                        groceryRow(for: line)
                    }
                }
            }
        }
    }

    private var modePicker: some View {
        Picker("This Week View", selection: $selectedMode) {
            ForEach(WeekPlanDisplayMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .background {
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.9))
        }
    }

    private func groceryRow(for line: ShoppingListLine) -> some View {
        HStack(spacing: 12) {
            IngredientThumbnailView(photoData: line.photoData)

            Text(line.ingredientName)
            Spacer()
            Text(line.formattedAmount)
                .foregroundStyle(.secondary)
        }
    }

    private func prepareCalendarSelection() {
        isUpdatingCalendar = true

        Task { @MainActor in
            defer {
                isUpdatingCalendar = false
            }

            do {
                calendarLists = try await calendarExporter.availableCalendars()

                guard !calendarLists.isEmpty else {
                    throw CalendarExportError.noWritableCalendars
                }

                showingCalendarListPicker = true
            } catch {
                showCalendarError(error)
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

    private func addCalendarEvents(to calendar: CalendarListOption) {
        isUpdatingCalendar = true

        Task { @MainActor in
            defer {
                isUpdatingCalendar = false
            }

            do {
                let eventCount = try await calendarExporter.export(
                    calendarMealPortions,
                    weekStarting: calendarWeekStarting,
                    dayCount: WeekPlanCalendar.dayCount,
                    to: calendar
                )
                remember(calendar)
                exportAlert = ReminderExportAlert(
                    title: "Meals Added to Calendar",
                    message: "\(eventCount) meal plan events were added to \(calendar.title)."
                )
            } catch {
                showCalendarError(error, for: calendar)
            }
        }
    }

    private func clearCalendarEvents(from calendar: CalendarListOption) {
        isUpdatingCalendar = true

        Task { @MainActor in
            defer {
                isUpdatingCalendar = false
            }

            do {
                let removedCount = try await calendarExporter
                    .clearAutomaticallyAddedEvents(from: calendar)
                exportAlert = ReminderExportAlert(
                    title: "Calendar Events Cleared",
                    message: "\(removedCount) automatically added events were removed from \(calendar.title)."
                )
            } catch {
                showCalendarError(error, for: calendar)
            }
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

    private func remember(_ calendar: CalendarListOption) {
        lastCalendarID = calendar.id
        lastCalendarName = calendar.title
    }

    private func rememberSyncCalendar(_ calendar: CalendarListOption) {
        syncCalendarID = calendar.id
        syncCalendarName = calendar.title
    }

    private func remember(_ list: ReminderListOption) {
        lastRemindersListID = list.id
        lastRemindersListName = list.title
    }

    private func forgetRememberedCalendar(ifMatching calendar: CalendarListOption) {
        guard calendar.id == lastCalendarID else { return }
        lastCalendarID = ""
        lastCalendarName = ""
    }

    private func forgetSyncCalendar(ifMatching calendar: CalendarListOption) {
        guard calendar.id == syncCalendarID else { return }
        syncCalendarID = ""
        syncCalendarName = ""
    }

    private func forgetRememberedList(ifMatching list: ReminderListOption) {
        guard list.id == lastRemindersListID else { return }
        lastRemindersListID = ""
        lastRemindersListName = ""
    }

    private func showCalendarError(_ error: Error, for calendar: CalendarListOption? = nil) {
        if let calendar,
           let calendarError = error as? CalendarExportError,
           calendarError == .calendarUnavailable {
            forgetRememberedCalendar(ifMatching: calendar)
        }

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
            if let selectedSyncCalendar,
               let calendarError = error as? CalendarExportError,
               calendarError == .calendarUnavailable {
                forgetSyncCalendar(ifMatching: selectedSyncCalendar)
            }
        }
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

    private func movePortions(withIDs idStrings: [String], to dayOffset: Int) {
        let ids = Set(idStrings.compactMap(UUID.init(uuidString:)))
        let portions = currentPlanPortions.filter { ids.contains($0.id) }
        guard !portions.isEmpty else { return }

        let clampedDayOffset = min(max(dayOffset, 0), WeekPlanCalendar.dayCount - 1)
        let firstSortOrder = nextSortOrder(for: clampedDayOffset)

        withAnimation(.snappy) {
            for (index, portion) in portions.enumerated() {
                portion.dayOffset = clampedDayOffset
                portion.sortOrder = firstSortOrder + index
                portion.weekPlan = currentPlan
            }
        }

        try? modelContext.save()
    }

    private func nextSortOrder(for dayOffset: Int) -> Int {
        let maxSortOrder = currentPlanPortions
            .filter { $0.dayOffset == dayOffset }
            .map(\.sortOrder)
            .max()

        return (maxSortOrder ?? -1) + 1
    }

    private func syncCalendarPortions(for plan: WeekPlan) {
        let meals = (plan.plannedMeals ?? [])
        let mealIDs = Set(meals.map(\.id))
        let allPortions = (try? modelContext.fetch(FetchDescriptor<PlannedMealPortion>())) ?? mealPortions
        let planPortions = allPortions.filter { portion in
            portion.weekPlan?.id == plan.id ||
            portion.plannedMeal?.weekPlan?.id == plan.id
        }
        var nextMondaySortOrder = (
            planPortions
                .filter { $0.dayOffset == 0 }
                .map(\.sortOrder)
                .max() ?? -1
        ) + 1
        var didChange = false

        for portion in planPortions {
            if portion.dayOffset < 0 || portion.dayOffset >= WeekPlanCalendar.dayCount {
                portion.dayOffset = 0
                didChange = true
            }

            guard let plannedMeal = portion.plannedMeal,
                  mealIDs.contains(plannedMeal.id) else {
                modelContext.delete(portion)
                didChange = true
                continue
            }

            if portion.weekPlan?.id != plan.id {
                portion.weekPlan = plan
                didChange = true
            }
        }

        for meal in meals {
            let expectedCount = PlannedMealPortion.portionCount(for: meal)
            let existingPortions = planPortions
                .filter { $0.plannedMeal?.id == meal.id }
                .sorted { lhs, rhs in
                    if lhs.dayOffset != rhs.dayOffset {
                        return lhs.dayOffset < rhs.dayOffset
                    }
                    return lhs.sortOrder < rhs.sortOrder
                }

            if existingPortions.count < expectedCount {
                let missingCount = expectedCount - existingPortions.count

                for index in 0..<missingCount {
                    modelContext.insert(
                        PlannedMealPortion(
                            dayOffset: 0,
                            sortOrder: nextMondaySortOrder + index,
                            weekPlan: plan,
                            plannedMeal: meal
                        )
                    )
                    didChange = true
                }

                nextMondaySortOrder += missingCount
            } else if existingPortions.count > expectedCount {
                for portion in existingPortions.suffix(existingPortions.count - expectedCount) {
                    modelContext.delete(portion)
                    didChange = true
                }
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }
}

private enum WeekPlanDisplayMode: String, CaseIterable, Identifiable {
    case calendar
    case list
    case groceryList

    var id: Self { self }

    var title: String {
        switch self {
        case .calendar:
            "Calendar"
        case .list:
            "Meals"
        case .groceryList:
            "Grocery List"
        }
    }
}

enum WeekPlanAutomationDefaults {
    static let removeMealsAtNewWeekKey = "removeMealsAtStartOfNewWeek"
    static let weekStartDayKey = "mealCleanupWeekStartDay"
}

enum WeekStartDay: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sunday:
            "Sunday"
        case .monday:
            "Monday"
        case .tuesday:
            "Tuesday"
        case .wednesday:
            "Wednesday"
        case .thursday:
            "Thursday"
        case .friday:
            "Friday"
        case .saturday:
            "Saturday"
        }
    }

    func startOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysSinceWeekStart = (weekday - rawValue + 7) % 7

        return calendar.date(
            byAdding: .day,
            value: -daysSinceWeekStart,
            to: startOfDay
        ) ?? startOfDay
    }
}

@MainActor
enum WeekPlanAutomation {
    static func runLaunchMaintenance(in modelContext: ModelContext) async {
        do {
            _ = try removeMealsAtStartOfNewWeekIfNeeded(in: modelContext)

            guard UserDefaults.standard.bool(forKey: CalendarSyncDefaults.isEnabledKey),
                  let selectedCalendar = CalendarSyncDefaults.selectedCalendar else {
                return
            }

            _ = try await syncCurrentWeekCalendar(
                in: modelContext,
                to: selectedCalendar
            )
        } catch {
            if let calendarError = error as? CalendarExportError,
               calendarError == .calendarUnavailable {
                CalendarSyncDefaults.forgetSelectedCalendar()
            }
        }
    }

    static func removeMealsAtStartOfNewWeekIfNeeded(in modelContext: ModelContext) throws -> Int {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: WeekPlanAutomationDefaults.removeMealsAtNewWeekKey) else {
            return 0
        }

        let weekStartDay = WeekStartDay(
            rawValue: defaults.integer(forKey: WeekPlanAutomationDefaults.weekStartDayKey)
        ) ?? .monday
        let currentWeekStart = weekStartDay.startOfWeek(containing: Date())

        return try removeMealsAddedBefore(currentWeekStart, in: modelContext)
    }

    static func syncCurrentWeekCalendar(
        in modelContext: ModelContext,
        to calendar: CalendarListOption
    ) async throws -> Int {
        let plans = (try? modelContext.fetch(FetchDescriptor<WeekPlan>())) ?? []
        let planWeekStarting = Calendar.current.startOfWeek(containing: Date())
        let currentPlan = plans.first {
            Calendar.current.isDate($0.weekStarting, inSameDayAs: planWeekStarting)
        }
        let portions = currentPlan.map {
            currentPlanPortions(for: $0, in: modelContext)
        } ?? []

        return try await CalendarEventExporter().replaceAutomaticallyAddedEvents(
            portions,
            weekStarting: WeekPlanCalendar.mondayStart(containing: Date()),
            dayCount: WeekPlanCalendar.dayCount,
            to: calendar
        )
    }

    private static func removeMealsAddedBefore(
        _ cutoff: Date,
        in modelContext: ModelContext
    ) throws -> Int {
        let meals = (try? modelContext.fetch(FetchDescriptor<PlannedMeal>())) ?? []
        let removedMeals = meals.filter {
            $0.createdAt < cutoff
        }
        guard !removedMeals.isEmpty else { return 0 }

        let removedMealIDs = Set(removedMeals.map(\.id))
        let portions = (try? modelContext.fetch(FetchDescriptor<PlannedMealPortion>())) ?? []

        for portion in portions where portion.plannedMeal.map({ removedMealIDs.contains($0.id) }) == true {
            modelContext.delete(portion)
        }

        for meal in removedMeals {
            modelContext.delete(meal)
        }

        try modelContext.save()
        return removedMeals.count
    }

    private static func currentPlanPortions(
        for plan: WeekPlan,
        in modelContext: ModelContext
    ) -> [PlannedMealPortion] {
        let sortDescriptors = [
            SortDescriptor(\PlannedMealPortion.dayOffset),
            SortDescriptor(\PlannedMealPortion.sortOrder),
        ]
        let portions = (
            try? modelContext.fetch(
                FetchDescriptor<PlannedMealPortion>(sortBy: sortDescriptors)
            )
        ) ?? []

        return portions.filter { portion in
            portion.weekPlan?.id == plan.id ||
            portion.plannedMeal?.weekPlan?.id == plan.id
        }
    }
}

private struct WeekPlanMealDaySection: Identifiable {
    let dayOffset: Int
    let date: Date
    let rows: [WeekPlanMealDayRow]

    var id: Int { dayOffset }

    var title: String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct WeekPlanMealDayRow: Identifiable {
    let id: String
    let groupKey: String
    let recipe: Recipe?
    let title: String
    var portionCount: Int
    var plannedMealIDs: Set<UUID>
    let firstSortIndex: Int

    var portionCountText: String {
        "\(portionCount) \(portionCount == 1 ? "portion" : "portions")"
    }
}

private enum WeekPlanCalendar {
    static let dayCount = 8
    static let coordinateSpaceName = "WeekPlanCalendarCoordinateSpace"

    static func mondayStart(containing date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
    }
}

private struct WeekPlanCalendarView: View {
    let weekStarting: Date
    let portions: [PlannedMealPortion]
    let movePortions: ([String], Int) -> Void

    @State private var dayFrames: [Int: CGRect] = [:]
    @State private var portionDrag: WeekPlanPortionDrag?

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 62), spacing: 8),
        count: 4
    )

    private var days: [WeekPlanCalendarDay] {
        (0..<WeekPlanCalendar.dayCount).map { offset in
            let date = Calendar.current.date(
                byAdding: .day,
                value: offset,
                to: weekStarting
            ) ?? weekStarting

            return WeekPlanCalendarDay(offset: offset, date: date)
        }
    }

    private var dropTargetDayOffset: Int? {
        guard let location = portionDrag?.location else { return nil }
        return dayOffset(containing: location)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(days) { day in
                    WeekPlanDayCell(
                        day: day,
                        portions: portions(for: day),
                        draggingPortionID: portionDrag?.portionID,
                        isDropTarget: dropTargetDayOffset == day.offset,
                        onPortionDragChanged: handlePortionDragChanged,
                        onPortionDragEnded: handlePortionDragEnded
                    )
                }
            }

            if let portionDrag,
               let draggedPortion = portions.first(where: { $0.id == portionDrag.portionID }) {
                MealPortionChipView(portion: draggedPortion)
                    .scaleEffect(1.18)
                    .position(portionDrag.location)
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
        }
        .coordinateSpace(name: WeekPlanCalendar.coordinateSpaceName)
        .onPreferenceChange(WeekPlanDayFramePreferenceKey.self) { frames in
            dayFrames = frames
        }
        .padding(.vertical, 4)
        
        Text("Hold and drag meals to assign them to a day. To remove a meal, swipe to delete it from the Meals tab.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func portions(for day: WeekPlanCalendarDay) -> [PlannedMealPortion] {
        portions
            .filter { $0.dayOffset == day.offset }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }

                return (lhs.plannedMeal?.sortOrder ?? 0) < (rhs.plannedMeal?.sortOrder ?? 0)
            }
    }

    private func handlePortionDragChanged(
        _ portion: PlannedMealPortion,
        value: DragGesture.Value
    ) {
        portionDrag = WeekPlanPortionDrag(portionID: portion.id, location: value.location)
    }

    private func handlePortionDragEnded(
        _ portion: PlannedMealPortion,
        value: DragGesture.Value
    ) {
        let targetDayOffset = dayOffset(containing: value.location)

        withAnimation(.snappy) {
            portionDrag = nil
        }

        guard let targetDayOffset else { return }
        movePortions([portion.id.uuidString], targetDayOffset)
    }

    private func dayOffset(containing location: CGPoint) -> Int? {
        dayFrames
            .first { _, frame in frame.contains(location) }
            .map(\.key)
    }
}

private struct WeekPlanCalendarDay: Identifiable {
    let offset: Int
    let date: Date

    var id: Int { offset }

    var weekdayTitle: String {
        date.formatted(.dateTime.weekday(.wide))
    }
}

private struct WeekPlanPortionDrag: Equatable {
    let portionID: UUID
    var location: CGPoint
}

private struct WeekPlanDayFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct WeekPlanDayCell: View {
    let day: WeekPlanCalendarDay
    let portions: [PlannedMealPortion]
    let draggingPortionID: UUID?
    let isDropTarget: Bool
    let onPortionDragChanged: (PlannedMealPortion, DragGesture.Value) -> Void
    let onPortionDragEnded: (PlannedMealPortion, DragGesture.Value) -> Void

    private let chipColumns = [
        GridItem(.adaptive(minimum: 30), spacing: 4),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text(day.weekdayTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.horizontal, 3)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .tertiarySystemFill))

            VStack(alignment: .leading, spacing: 0) {
                LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 4) {
                    ForEach(portions) { portion in
                        MealPortionChipView(portion: portion)
                            .opacity(draggingPortionID == portion.id ? 0.22 : 1)
                            .scaleEffect(draggingPortionID == portion.id ? 0.92 : 1)
                            .highPriorityGesture(
                                DragGesture(
                                    minimumDistance: 1,
                                    coordinateSpace: .named(WeekPlanCalendar.coordinateSpaceName)
                                )
                                .onChanged { value in
                                    onPortionDragChanged(portion, value)
                                }
                                .onEnded { value in
                                    onPortionDragEnded(portion, value)
                                }
                            )
                            .animation(.snappy(duration: 0.16), value: draggingPortionID)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(6)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: WeekPlanDayFramePreferenceKey.self,
                    value: [
                        day.offset: proxy.frame(
                            in: .named(WeekPlanCalendar.coordinateSpaceName)
                        ),
                    ]
                )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.24), lineWidth: 0.5)

            if isDropTarget {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.65), lineWidth: 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(day.weekdayTitle)
    }
}

private struct MealPortionChipView: View {
    let portion: PlannedMealPortion

    private var recipe: Recipe? {
        portion.plannedMeal?.recipe
    }

    var body: some View {
        Group {
            if let image = recipe?.photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.16))

                    Text(recipe?.monogram ?? "?")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.background, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .contentShape(Circle())
        .accessibilityLabel(recipe?.name ?? "Deleted recipe")
    }
}

private extension Recipe {
    var monogram: String {
        let words = name
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .prefix(2)
            .compactMap(\.first)

        let initials = String(words).uppercased()
        return initials.isEmpty ? "?" : initials
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
