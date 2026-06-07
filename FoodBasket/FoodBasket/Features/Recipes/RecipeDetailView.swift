//
//  RecipeDetailView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import LinkPresentation
import SwiftData
import SwiftUI
import UIKit

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]
    @Query(sort: [
        SortDescriptor(\PlannedMealPortion.dayOffset),
        SortDescriptor(\PlannedMealPortion.sortOrder),
    ]) private var mealPortions: [PlannedMealPortion]
    let recipe: Recipe
    let onOpenThisWeekCalendar: (Set<UUID>) -> Void
    @State private var showingAddIngredient = false
    @State private var showingEditRecipe = false
    @State private var showingCamera = false
    @State private var substitutedIngredientLine: RecipeIngredient?
    @State private var remindersExporter = RemindersExporter()
    @State private var reminderLists: [ReminderListOption] = []
    @State private var showingReminderListPicker = false
    @State private var isUpdatingReminders = false
    @State private var activeAlert: RecipeDetailAlert?
    @State private var isScrubbingRating = false
    @AppStorage(ReminderListDefaults.idKey) private var lastRemindersListID = ""
    @AppStorage(ReminderListDefaults.nameKey) private var lastRemindersListName = ""
    @AppStorage(WeekPlanAutomationDefaults.removeMealsAtNewWeekKey) private var removeMealsAtNewWeek = false
    @AppStorage(WeekPlanAutomationDefaults.weekStartDayKey) private var weekStartDay = WeekStartDay.monday.rawValue

    init(
        recipe: Recipe,
        onOpenThisWeekCalendar: @escaping (Set<UUID>) -> Void = { _ in }
    ) {
        self.recipe = recipe
        self.onOpenThisWeekCalendar = onOpenThisWeekCalendar
    }

    private var ingredientLines: [RecipeIngredient] {
        (recipe.ingredientLines ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var shoppingListLines: [ShoppingListLine] {
        ShoppingListLine.makeLines(for: recipe)
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

    private var reminderSourceIdentifier: String {
        "recipe:\(recipe.id.uuidString)"
    }

    private var foodBasketWeekStartDay: WeekStartDay {
        WeekStartDay.foodBasketCalendarStartDay(
            removeMealsAtNewWeek: removeMealsAtNewWeek,
            rawValue: weekStartDay
        )
    }

    private var planWeekStarting: Date {
        foodBasketWeekStartDay.startOfWeek(containing: Date())
    }

    private var currentWeekPlan: WeekPlan? {
        plans.first {
            Calendar.current.isDate($0.weekStarting, inSameDayAs: planWeekStarting)
        }
    }

    private var currentWeekRecipeMeals: [PlannedMeal] {
        (currentWeekPlan?.plannedMeals ?? [])
            .filter { $0.recipe?.id == recipe.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentWeekRecipePortions: [PlannedMealPortion] {
        guard let currentWeekPlan else { return [] }

        let mealIDs = Set(currentWeekRecipeMeals.map(\.id))
        return mealPortions
            .filter { portion in
                let belongsToCurrentWeek = portion.weekPlan?.id == currentWeekPlan.id ||
                    portion.plannedMeal?.weekPlan?.id == currentWeekPlan.id
                guard belongsToCurrentWeek,
                      let plannedMeal = portion.plannedMeal else {
                    return false
                }

                return mealIDs.contains(plannedMeal.id)
            }
            .sorted { lhs, rhs in
                if lhs.dayOffset != rhs.dayOffset {
                    return lhs.dayOffset < rhs.dayOffset
                }

                return lhs.sortOrder < rhs.sortOrder
            }
    }

    private var isIncludedInThisWeek: Bool {
        !currentWeekRecipeMeals.isEmpty
    }

    private var currentWeekMealMultiplier: Double {
        currentWeekRecipeMeals.reduce(0) { total, meal in
            total + max(meal.quantityMultiplier, 0)
        }
    }

    private var currentWeekRecipePortionText: String {
        let count = currentWeekRecipePortions.count
        return "\(count) \(count == 1 ? "portion" : "portions")"
    }

    private var currentWeekMealMultiplierText: String {
        "Having \(currentWeekMealFrequencyText) this week"
    }

    private var currentWeekMealFrequencyText: String {
        switch currentWeekMealMultiplier {
        case 1:
            "once"
        case 2:
            "twice"
        default:
            "\(formattedCount(currentWeekMealMultiplier)) times"
        }
    }

    private var clampedRecipeRating: Int {
        min(max(recipe.rating, 0), 5)
    }

    private var externalURL: URL? {
        recipe.externalURL
    }

    var body: some View {
        recipeContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                recipeToolbar
            }
            .sheet(isPresented: $showingEditRecipe) {
                NavigationStack {
                    RecipeFormView(recipe: recipe)
                }
            }
            .sheet(isPresented: $showingAddIngredient) {
                NavigationStack {
                    AddIngredientToRecipeView(recipe: recipe)
                }
            }
            .sheet(isPresented: $showingReminderListPicker) {
                NavigationStack {
                    ExternalListPickerView(
                        isCalendar: false,
                        options: reminderLists
                    ) { list in
                        addReminders(to: list)
                    }
                }
            }
            .sheet(item: $substitutedIngredientLine) { line in
                NavigationStack {
                    SubstituteRecipeIngredientView(line: line)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    recipe.photoData = image.recipePhotoData
                    try? modelContext.save()
                }
                .ignoresSafeArea()
            }
            .alert(item: $activeAlert) { alert in
                recipeAlert(for: alert)
            }
    }

    private var recipeContent: some View {
        List {
            heroImageRow
            recipeSummaryRow
            recipeActionRow
            ingredientsSection
            methodSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
        }
        .ignoresSafeArea(edges: .top)
    }

    private var heroImageRow: some View {
        RecipeHeroImageView(photoData: recipe.photoData, takePhoto: takePhoto)
            .overlay(alignment: .bottom) {
                if isIncludedInThisWeek {
                    thisWeekMealMultiplierControl
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private var thisWeekMealMultiplierControl: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                
                Text(currentWeekMealMultiplierText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(currentWeekRecipePortionText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                mealMultiplierEditButton(
                    systemImage: "minus",
                    accessibilityLabel: "Decrease meal multiplier"
                ) {
                    adjustThisWeekMealMultiplier(by: -1)
                }
                .disabled(currentWeekMealMultiplier <= 0)

                mealMultiplierEditButton(
                    systemImage: "plus",
                    accessibilityLabel: "Increase meal multiplier"
                ) {
                    adjustThisWeekMealMultiplier(by: 1)
                }
            }
        }
        .padding(.vertical, 11)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
        .frame(maxWidth: 380)
        .accessibilityElement(children: .contain)
    }

    private func mealMultiplierEditButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(width: 34, height: 34)
                .background(Color(uiColor: .systemBackground).opacity(0.9), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(uiColor: .label))
        .accessibilityLabel(accessibilityLabel)
    }

    private var recipeSummaryRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipe.name)
                .font(.largeTitle.bold())
                .fontDesign(.rounded)

            HStack(spacing: 8) {
                Image(systemName: "clock")
                Text("\(recipe.cookingTimeMinutes) min")
                Image(systemName: "person.2")
                Text("\(recipe.serves)")
            }
            .foregroundStyle(.secondary)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var recipeActionRow: some View {
        HStack {
            groceryListButton
            ratingPicker
        }
        .listRowSeparator(.hidden)
        .padding(.bottom, -15)
    }

    @ViewBuilder
    private var ingredientsSection: some View {
        Section("Ingredients") {
            if ingredientLines.isEmpty {
                Text("No ingredients yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(ingredientLines) { line in
                    ingredientLineRow(for: line)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            ingredientSwipeActions(for: line)
                        }
                }
            }
        }
    }

    private var methodSection: some View {
        Section("Method") {
            Text(recipe.method.isEmpty ? "No method added." : recipe.method)
                .foregroundStyle(recipe.method.isEmpty ? .secondary : .primary)

            if let externalURL {
                RecipeExternalURLPreviewRow(url: externalURL)
            }
        }
    }

    @ViewBuilder
    private func ingredientSwipeActions(for line: RecipeIngredient) -> some View {
        Button(role: .destructive) {
            deleteIngredientLine(line)
        } label: {
            Label("Remove", systemImage: "xmark")
        }

        Button {
            substitutedIngredientLine = line
        } label: {
            Label("Substitute", systemImage: "arrow.triangle.2.circlepath")
        }
        .tint(.purple)
    }

    @ToolbarContentBuilder
    private var recipeToolbar: some ToolbarContent {
        
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingEditRecipe = true
            } label: {
                Text("Edit")
            }
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        
        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) {
                activeAlert = .deleteConfirmation
            } label: {
                Label("Delete Recipe", systemImage: "trash")
            }
            .tint(.red)
        }

        if let externalURL {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openURL(externalURL)
                } label: {
                    Label("Open Recipe Website", systemImage: "safari")
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                takePhoto()
            } label: {
                Label("Take Meal Photo", systemImage: "camera")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingAddIngredient = true
            } label: {
                Label("Add Ingredient", systemImage: "plus")
            }
        }
    }

    private var groceryListButton: some View {
        Menu {
            reminderContextMenu
        } label: {
            groceryListButtonLabel
        } primaryAction: {
            addToThisWeek()
        }
        .buttonStyle(.bordered)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    playGroceryMenuHaptic()
                }
        )
    }

    private var groceryListButtonLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "refrigerator")
                .font(.subheadline)
            Text("Have this week")
        }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .foregroundColor(Color(uiColor: .label))
    }

    @ViewBuilder
    private var reminderContextMenu: some View {
        Button {
            prepareReminderListSelection()
        } label: {
            Label("Add to Reminders List", systemImage: "list.bullet")
        }
        .disabled(shoppingListLines.isEmpty || isUpdatingReminders)

        if let rememberedReminderList {
            
            Divider()
            
            Button {
                addReminders(to: rememberedReminderList)
            } label: {
                Label("Add to \(rememberedReminderList.title)", systemImage: "plus")
            }
            .disabled(shoppingListLines.isEmpty || isUpdatingReminders)

            Button(role: .destructive) {
                clearReminders(from: rememberedReminderList)
            } label: {
                Label("Remove Ingredients from \(rememberedReminderList.title)", systemImage: "trash")
            }
            .disabled(isUpdatingReminders)
        }
        
        Divider()
        
        Button {
            addToThisWeek()
        } label: {
            Label("Add to This Week", systemImage: "refrigerator")
        }
        .disabled(isUpdatingReminders)
    }

    private func addToThisWeek() {
        if let duplicateUpdate = pendingDuplicateThisWeekUpdate() {
            activeAlert = .duplicateThisWeekUpdate(duplicateUpdate)
            return
        }

        createThisWeekMeal(openCalendarAfterSave: true)
    }

    private func createThisWeekMeal(openCalendarAfterSave: Bool) {
        let plan = SeedData.weekPlan(
            starting: planWeekStarting,
            existing: plans,
            in: modelContext
        )
        let meal = PlannedMeal(
            quantityMultiplier: 1,
            sortOrder: plan.plannedMeals?.count ?? 0,
            weekPlan: plan,
            recipe: recipe
        )
        plan.plannedMeals = (plan.plannedMeals ?? []) + [meal]
        modelContext.insert(meal)

        let firstSortOrder = nextMondayPortionSortOrder(for: plan)
        var createdPortionIDs: Set<UUID> = []

        for index in 0..<PlannedMealPortion.portionCount(for: meal) {
            let portion = PlannedMealPortion(
                dayOffset: 0,
                sortOrder: firstSortOrder + index,
                weekPlan: plan,
                plannedMeal: meal
            )
            createdPortionIDs.insert(portion.id)
            modelContext.insert(portion)
        }

        try? modelContext.save()
        playAddToWeekHaptic()

        if openCalendarAfterSave {
            onOpenThisWeekCalendar(createdPortionIDs)
        }
    }

    private func pendingDuplicateThisWeekUpdate() -> ThisWeekDuplicateUpdate? {
        guard let plan = currentWeekPlan else { return nil }

        let matchingMeals = (plan.plannedMeals ?? [])
            .filter { $0.recipe?.id == recipe.id }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let firstMatchingMeal = matchingMeals.first else { return nil }

        let currentIngredientCount = matchingMeals.reduce(0) { total, meal in
            total + max(meal.quantityMultiplier, 0)
        }

        return ThisWeekDuplicateUpdate(
            mealID: firstMatchingMeal.id,
            updatedIngredientCount: currentIngredientCount + 1
        )
    }

    private func updateThisWeekCount(for update: ThisWeekDuplicateUpdate) {
        guard let plan = currentWeekPlan,
              let meal = (plan.plannedMeals ?? []).first(where: { $0.id == update.mealID }) else {
            createThisWeekMeal(openCalendarAfterSave: false)
            return
        }

        meal.quantityMultiplier += 1
        addMissingPortions(for: meal, in: plan)
        try? modelContext.save()
        playAddToWeekHaptic()
    }

    private func addMissingPortions(for meal: PlannedMeal, in plan: WeekPlan) {
        let existingPortions = allPlannedMealPortions()
            .filter { $0.plannedMeal?.id == meal.id }
        let missingCount = PlannedMealPortion.portionCount(for: meal) - existingPortions.count

        guard missingCount > 0 else { return }

        let firstSortOrder = nextMondayPortionSortOrder(for: plan)
        for index in 0..<missingCount {
            modelContext.insert(
                PlannedMealPortion(
                    dayOffset: 0,
                    sortOrder: firstSortOrder + index,
                    weekPlan: plan,
                    plannedMeal: meal
                )
            )
        }
    }

    private func adjustThisWeekMealMultiplier(by delta: Double) {
        guard delta != 0 else { return }

        setThisWeekMealMultiplier(currentWeekMealMultiplier + delta)
        try? modelContext.save()
        playMealMultiplierEditHaptic()
    }

    private func setThisWeekMealMultiplier(_ multiplier: Double) {
        guard let plan = currentWeekPlan,
              let meal = currentWeekRecipeMeals.first else { return }

        let clampedMultiplier = max(multiplier, 0)

        guard clampedMultiplier > 0 else {
            removeFromThisWeek()
            return
        }

        let portions = currentWeekRecipePortions
        let duplicateMeals = currentWeekRecipeMeals.dropFirst()

        for portion in portions {
            portion.weekPlan = plan
            portion.plannedMeal = meal
        }

        for duplicateMeal in duplicateMeals {
            modelContext.delete(duplicateMeal)
        }

        meal.quantityMultiplier = clampedMultiplier
        syncPortions(for: meal, in: plan, existingPortions: portions)
    }

    private func removeFromThisWeek() {
        for portion in currentWeekRecipePortions {
            modelContext.delete(portion)
        }

        for meal in currentWeekRecipeMeals {
            modelContext.delete(meal)
        }
    }

    private func syncPortions(
        for meal: PlannedMeal,
        in plan: WeekPlan,
        existingPortions: [PlannedMealPortion]
    ) {
        let expectedCount = PlannedMealPortion.portionCount(for: meal)

        if existingPortions.count < expectedCount {
            let firstSortOrder = nextMondayPortionSortOrder(for: plan)
            let missingCount = expectedCount - existingPortions.count

            for index in 0..<missingCount {
                modelContext.insert(
                    PlannedMealPortion(
                        dayOffset: 0,
                        sortOrder: firstSortOrder + index,
                        weekPlan: plan,
                        plannedMeal: meal
                    )
                )
            }
        } else if existingPortions.count > expectedCount {
            for portion in existingPortions.suffix(existingPortions.count - expectedCount) {
                modelContext.delete(portion)
            }
        }
    }

    private var ratingPicker: some View {
        Button {} label: {
            ratingStars(for: clampedRecipeRating)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .fontWeight(.bold)
        }
        .buttonStyle(.bordered)
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                guard value.isScrubbing else { return }

                                isScrubbingRating = true
                                setRating(at: value.location.x, in: proxy.size.width)
                            }
                            .onEnded { value in
                                if isScrubbingRating {
                                    setRating(at: value.location.x, in: proxy.size.width)
                                } else {
                                    setTappedRating(at: value.location.x, in: proxy.size.width)
                                }

                                isScrubbingRating = false
                            }
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recipe rating")
        .accessibilityValue(ratingAccessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setRating(clampedRecipeRating + 1)
            case .decrement:
                setRating(clampedRecipeRating - 1)
            @unknown default:
                break
            }
        }
    }

    private func ratingStars(for rating: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
            }
        }
        .foregroundStyle(.yellow)
    }

    @ViewBuilder
    private func ingredientLineRow(for line: RecipeIngredient) -> some View {
        if let ingredient = line.ingredient {
            NavigationLink {
                IngredientDetailView(
                    ingredient: ingredient,
                    recipeIngredientLine: line
                )
            } label: {
                ingredientLineContent(for: line)
            }
        } else {
            ingredientLineContent(for: line)
        }
    }

    private func ingredientLineContent(for line: RecipeIngredient) -> some View {
        HStack(spacing: 12) {
            IngredientThumbnailView(photoData: line.ingredient?.photoData)

            VStack(alignment: .leading, spacing: 2) {
                Text(line.ingredient?.name ?? "Deleted ingredient")

                if !line.trimmedPreparationMethod.isEmpty {
                    Text(line.trimmedPreparationMethod)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(line.formattedQuantity)
                .foregroundStyle(.secondary)
        }
    }

    private func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            activeAlert = .cameraUnavailable
            return
        }

        showingCamera = true
    }

    private func deleteIngredientLine(_ line: RecipeIngredient) {
        recipe.ingredientLines?.removeAll { $0.id == line.id }
        line.recipe?.ingredientLines?.removeAll { $0.id == line.id }
        modelContext.delete(line)
        try? modelContext.save()
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
                try await remindersExporter.export(
                    shoppingListLines,
                    to: list,
                    sourceIdentifier: reminderSourceIdentifier
                )
                remember(list)
                activeAlert = .export(
                    ReminderExportAlert(
                        title: "Grocery List Added",
                        message: "\(shoppingListLines.count) items from \(recipe.name) were added to \(list.title)."
                    )
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
                    from: list,
                    sourceIdentifier: reminderSourceIdentifier
                )
                activeAlert = .export(
                    ReminderExportAlert(
                        title: "Grocery List Removed",
                        message: "\(removedCount) items from \(recipe.name) were removed from \(list.title)."
                    )
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

    private func nextMondayPortionSortOrder(for plan: WeekPlan) -> Int {
        let maxSortOrder = allPlannedMealPortions()
            .filter { $0.weekPlan?.id == plan.id && $0.dayOffset == 0 }
            .map(\.sortOrder)
            .max()

        return (maxSortOrder ?? -1) + 1
    }

    private func allPlannedMealPortions() -> [PlannedMealPortion] {
        (try? modelContext.fetch(FetchDescriptor<PlannedMealPortion>())) ?? []
    }

    private func showRemindersError(_ error: Error, for list: ReminderListOption? = nil) {
        if let list,
           let remindersError = error as? RemindersExportError,
           remindersError == .listUnavailable {
            forgetRememberedList(ifMatching: list)
        }

        activeAlert = .export(
            ReminderExportAlert(
                title: "Unable to Update Reminders",
                message: error.localizedDescription
            )
        )
    }

    private func setRating(_ rating: Int) {
        let clampedRating = min(max(rating, 0), 5)
        guard recipe.rating != clampedRating else { return }

        recipe.rating = clampedRating
        try? modelContext.save()
        playRatingSelectionHaptic()
    }

    private func setRating(at xPosition: CGFloat, in width: CGFloat) {
        setRating(rating(at: xPosition, in: width))
    }

    private func setTappedRating(at xPosition: CGFloat, in width: CGFloat) {
        let tappedRating = rating(at: xPosition, in: width)

        if tappedRating == clampedRecipeRating {
            setRating(tappedRating - 1)
        } else {
            setRating(tappedRating)
        }
    }

    private func rating(at xPosition: CGFloat, in width: CGFloat) -> Int {
        guard width > 0 else { return 1 }

        let clampedXPosition = min(max(xPosition, 0), width)
        let rating = Int(clampedXPosition / (width / 5)) + 1
        return min(rating, 5)
    }

    private var ratingAccessibilityValue: String {
        switch clampedRecipeRating {
        case 1:
            "1 star"
        default:
            "\(clampedRecipeRating) stars"
        }
    }

    private func formattedCount(_ count: Double) -> String {
        count.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func duplicateThisWeekUpdateMessage(for update: ThisWeekDuplicateUpdate) -> String {
        """
        This recipe is already in This Week. Do you want to increase \
        the meal multiplier to \(formattedCount(update.updatedIngredientCount))x?
        """
    }

    private func recipeAlert(for alert: RecipeDetailAlert) -> Alert {
        switch alert {
        case .cameraUnavailable:
            Alert(
                title: Text("Camera Unavailable"),
                message: Text("A camera is not available on this device."),
                dismissButton: .default(Text("OK"))
            )
        case .duplicateThisWeekUpdate(let update):
            Alert(
                title: Text("Recipe Already Added"),
                message: Text(duplicateThisWeekUpdateMessage(for: update)),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .default(Text("Update multiplier")) {
                    updateThisWeekCount(for: update)
                }
            )
        case .export(let exportAlert):
            Alert(
                title: Text(exportAlert.title),
                message: Text(exportAlert.message),
                dismissButton: .default(Text("OK"))
            )
        case .deleteConfirmation:
            Alert(
                title: Text("Delete Recipe?"),
                message: Text("This will delete \(recipe.name) and remove it from any week plans."),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .destructive(Text("Delete")) {
                    deleteRecipe()
                }
            )
        }
    }

    private func deleteRecipe() {
        for plannedMeal in recipe.plannedMeals ?? [] {
            modelContext.delete(plannedMeal)
        }

        modelContext.delete(recipe)
        try? modelContext.save()
        dismiss()
    }

    private func playGroceryMenuHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func playAddToWeekHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func playMealMultiplierEditHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func playRatingSelectionHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

private struct RecipeExternalURLPreviewRow: View {
    let url: URL
    @State private var metadata: LPLinkMetadata?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let metadata {
                RecipeLinkPreview(metadata: metadata)
                    .frame(minHeight: 92)
            } else {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.host ?? url.absoluteString)
                            .font(.headline)
                            .lineLimit(2)

                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .redacted(reason: isLoading ? .placeholder : [])
            }
        }
        .padding(.vertical, 4)
        .task(id: url) {
            await loadMetadata()
        }
        .accessibilityElement(children: .contain)
    }

    @MainActor
    private func loadMetadata() async {
        guard metadata == nil, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let provider = LPMetadataProvider()

        do {
            metadata = try await provider.startFetchingMetadata(for: url)
        } catch {
            let fallbackMetadata = LPLinkMetadata()
            fallbackMetadata.originalURL = url
            fallbackMetadata.url = url
            fallbackMetadata.title = url.host ?? url.absoluteString
            metadata = fallbackMetadata
        }
    }
}

private struct RecipeLinkPreview: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        LPLinkView(metadata: metadata)
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}

private enum RecipeDetailAlert: Identifiable {
    case cameraUnavailable
    case duplicateThisWeekUpdate(ThisWeekDuplicateUpdate)
    case export(ReminderExportAlert)
    case deleteConfirmation

    var id: String {
        switch self {
        case .cameraUnavailable:
            "camera-unavailable"
        case .duplicateThisWeekUpdate(let update):
            "duplicate-\(update.id.uuidString)"
        case .export(let alert):
            "export-\(alert.id.uuidString)"
        case .deleteConfirmation:
            "delete-confirmation"
        }
    }
}

private struct ThisWeekDuplicateUpdate: Identifiable {
    let id = UUID()
    let mealID: UUID
    let updatedIngredientCount: Double
}

private extension DragGesture.Value {
    var isScrubbing: Bool {
        abs(translation.width) > 4 || abs(translation.height) > 4
    }
}

private extension RecipeIngredient {
    var trimmedPreparationMethod: String {
        preparationMethod.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedQuantity: String {
        let amount = quantity.formatted(.number.precision(.fractionLength(0...2)))
        guard let symbol = ingredient?.unit?.symbol, !symbol.isEmpty else {
            return amount
        }
        return "\(amount) \(symbol)"
    }
}

#Preview("Recipe Detail") {
    let previewData = PreviewData()

    NavigationStack {
        RecipeDetailView(recipe: previewData.recipe)
    }
    .modelContainer(previewData.container)
}
