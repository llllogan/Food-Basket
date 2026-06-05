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
    @Query(sort: [
        SortDescriptor(\PlannedMealPortion.dayOffset),
        SortDescriptor(\PlannedMealPortion.sortOrder),
    ]) private var mealPortions: [PlannedMealPortion]

    @State private var selectedMode: WeekPlanDisplayMode
    @State private var showingAddMeal = false
    @State private var remindersExporter = RemindersExporter()
    @State private var reminderLists: [ReminderListOption] = []
    @State private var showingReminderListPicker = false
    @State private var isUpdatingReminders = false
    @State private var isAddGroceriesTipPresented = false
    @State private var exportAlert: ReminderExportAlert?
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
                pickerRow
                selectedRows
            }
            .listStyle(.plain)
            .navigationTitle("This Week")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
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
                            Label("Update Reminders", systemImage: "square.and.arrow.up")
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
            }
            .task(id: portionSyncKey) {
                guard let currentPlan else { return }
                syncCalendarPortions(for: currentPlan)
            }
        }
    }

    @ViewBuilder
    private var selectedRows: some View {
        switch selectedMode {
        case .calendar:
            calendarRow
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
    private var mealRows: some View {
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
            Text("Week of \(calendarWeekStarting.formatted(date: .abbreviated, time: .omitted))")
        }
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
    }

    private var modePicker: some View {
        Picker("This Week View", selection: $selectedMode) {
            ForEach(WeekPlanDisplayMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var pickerRow: some View {
        modePicker
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
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
            for portion in currentPlanPortions where portion.plannedMeal?.id == meal.id {
                modelContext.delete(portion)
            }
            modelContext.delete(meal)
        }
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
        var nextMondaySortOrder = (
            currentPlanPortions
                .filter { $0.dayOffset == 0 }
                .map(\.sortOrder)
                .max() ?? -1
        ) + 1
        var didChange = false

        for portion in mealPortions where portion.weekPlan?.id == plan.id {
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
        }

        for meal in meals {
            let expectedCount = PlannedMealPortion.portionCount(for: meal)
            let existingPortions = mealPortions
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
            "List"
        case .groceryList:
            "Grocery List"
        }
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
        
        Text("Hold and drag meals to assign them to a day. To remove a meal, swipe to delete it from the List tab.")
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
