//
//  RecipeDetailView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI
import UIKit

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe
    @State private var showingAddIngredient = false
    @State private var showingEditRecipe = false
    @State private var showingCamera = false
    @State private var showingCameraUnavailable = false
    @State private var substitutedIngredientLine: RecipeIngredient?
    @State private var remindersExporter = RemindersExporter()
    @State private var reminderLists: [ReminderListOption] = []
    @State private var showingReminderListPicker = false
    @State private var isUpdatingReminders = false
    @State private var exportAlert: ReminderExportAlert?
    @State private var isScrubbingRating = false
    @AppStorage(ReminderListDefaults.idKey) private var lastRemindersListID = ""
    @AppStorage(ReminderListDefaults.nameKey) private var lastRemindersListName = ""

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

    private var reminderButtonTitle: String {
        rememberedReminderList == nil ? "Add to ..." : "Add to Grocery List"
    }

    private var reminderSourceIdentifier: String {
        "recipe:\(recipe.id.uuidString)"
    }

    private var clampedRecipeRating: Int {
        min(max(recipe.rating, 0), 5)
    }

    var body: some View {
        List {
            RecipeHeroImageView(photoData: recipe.photoData, takePhoto: takePhoto)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            VStack(alignment: .leading, spacing: 10) {
                Text(recipe.name)
                    .font(.largeTitle.bold())
                
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
            
            HStack {
                groceryListButton
                ratingPicker
            }
            .listRowSeparator(.hidden)
            .padding(.bottom, -15)

            Section("Ingredients") {
                if ingredientLines.isEmpty {
                    Text("No ingredients yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ingredientLines) { line in
                        ingredientLineRow(for: line)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                    }
                }
            }

            Section("Method") {
                Text(recipe.method.isEmpty ? "No method added." : recipe.method)
                    .foregroundStyle(recipe.method.isEmpty ? .secondary : .primary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditRecipe = true
                } label: {
                    Text("Edit")
                }
            }
            
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            
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
                ReminderListPickerView(lists: reminderLists) { list in
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
        .alert("Camera Unavailable", isPresented: $showingCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A camera is not available on this device.")
        }
        .alert(item: $exportAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var groceryListButton: some View {
        Menu {
            reminderContextMenu
        } label: {
            groceryListButtonLabel
        } primaryAction: {
            addToRememberedReminderListOrChoose()
        }
        .buttonStyle(.bordered)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    playGroceryMenuHaptic()
                }
        )
        .disabled(shoppingListLines.isEmpty || isUpdatingReminders)
    }

    @ViewBuilder
    private var groceryListButtonLabel: some View {
        if isUpdatingReminders {
            ProgressView()
                .controlSize(.small)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
        } else {
            Text(reminderButtonTitle)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .foregroundColor(Color(uiColor: .label))
        }
    }

    @ViewBuilder
    private var reminderContextMenu: some View {
        if let rememberedReminderList {
            Button {
                addReminders(to: rememberedReminderList)
            } label: {
                Label("Add to \(rememberedReminderList.title)", systemImage: "plus")
            }
            .disabled(shoppingListLines.isEmpty || isUpdatingReminders)

            Button {
                prepareReminderListSelection()
            } label: {
                Label("Add to Reminders", systemImage: "list.bullet")
            }
            .disabled(shoppingListLines.isEmpty || isUpdatingReminders)

            Button(role: .destructive) {
                clearReminders(from: rememberedReminderList)
            } label: {
                Label("Remove from \(rememberedReminderList.title)", systemImage: "trash")
            }
            .disabled(isUpdatingReminders)
        } else {
            Button {
                prepareReminderListSelection()
            } label: {
                Label("Add to Reminders", systemImage: "list.bullet")
            }
            .disabled(shoppingListLines.isEmpty || isUpdatingReminders)
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
            showingCameraUnavailable = true
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

    private func addToRememberedReminderListOrChoose() {
        guard let rememberedReminderList else {
            prepareReminderListSelection()
            return
        }

        addReminders(to: rememberedReminderList)
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
                exportAlert = ReminderExportAlert(
                    title: "Grocery List Added",
                    message: "\(shoppingListLines.count) items from \(recipe.name) were added to \(list.title)."
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
                exportAlert = ReminderExportAlert(
                    title: "Grocery List Removed",
                    message: "\(removedCount) items from \(recipe.name) were removed from \(list.title)."
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

    private func playGroceryMenuHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func playRatingSelectionHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
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
