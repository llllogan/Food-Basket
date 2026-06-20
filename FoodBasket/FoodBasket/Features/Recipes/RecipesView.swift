//
//  RecipesView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData
import UIKit

private enum RecipeListTransitionSource: Hashable {
    case addRecipeToolbar
    case addRecipeEmptyState
    case addRecipeFilteredEmptyState
}

struct RecipesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query(sort: \MealType.name) private var mealTypes: [MealType]
    @Binding private var selectedRecipeID: UUID?
    private let onOpenThisWeekCalendar: (Set<UUID>) -> Void
    @Namespace private var recipeListTransitionNamespace
    @State private var navigationPath = NavigationPath()
    @State private var showingAddRecipe = false
    @State private var pendingCreatedRecipeID: UUID?
    @State private var addRecipeTransitionSource: RecipeListTransitionSource = .addRecipeToolbar
    @State private var showingImportRecipeAlert = false
    @State private var importURLText = ""
    @State private var isImportingRecipe = false
    @State private var importErrorMessage: String?
    @State private var showingImportError = false
    @State private var runningImportTask: Task<Void, Never>?
    @State private var searchText = ""
    @State private var sortMode = RecipeListSortMode.name
    @State private var selectedMealTypeFilterID: UUID?

    init(
        selectedRecipeID: Binding<UUID?> = .constant(nil),
        onOpenThisWeekCalendar: @escaping (Set<UUID>) -> Void = { _ in }
    ) {
        _selectedRecipeID = selectedRecipeID
        self.onOpenThisWeekCalendar = onOpenThisWeekCalendar
    }

    private var importURL: URL? {
        recipeURL(from: importURLText)
    }

    private func recipeURL(from text: String) -> URL? {
        let trimmedURL = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }

        if trimmedURL.contains("://") {
            return URL(string: trimmedURL)
        }

        return URL(string: "https://\(trimmedURL)")
    }

    private var selectedMealTypeFilterTitle: String {
        guard let selectedMealTypeFilterID,
              let selectedMealType = mealTypes.first(where: { $0.id == selectedMealTypeFilterID }) else {
            return "All"
        }

        return selectedMealType.name
    }

    @ViewBuilder
    private func zoomTransitionSource<Content: View>(
        id: RecipeListTransitionSource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 18.0, *) {
            content()
                .matchedTransitionSource(id: id, in: recipeListTransitionNamespace)
        } else {
            content()
        }
    }

    @ViewBuilder
    private func zoomTransitionDestination<Content: View>(
        id: RecipeListTransitionSource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 18.0, *) {
            content()
                .navigationTransition(.zoom(sourceID: id, in: recipeListTransitionNamespace))
        } else {
            content()
        }
    }

    private var filteredRecipes: [Recipe] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchMatchedRecipes: [Recipe]

        if trimmedSearchText.isEmpty {
            searchMatchedRecipes = recipes
        } else {
            searchMatchedRecipes = recipes.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(trimmedSearchText) ||
                (recipe.mealType?.name.localizedCaseInsensitiveContains(trimmedSearchText) ?? false)
            }
        }

        let visibleRecipes: [Recipe]
        if let selectedMealTypeFilterID {
            visibleRecipes = searchMatchedRecipes.filter {
                $0.mealType?.id == selectedMealTypeFilterID
            }
        } else {
            visibleRecipes = searchMatchedRecipes
        }

        return sortMode.sort(visibleRecipes)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if recipes.isEmpty {
                    ContentUnavailableView {
                        Label("No Recipes Yet", systemImage: "book.closed")
                    } description: {
                        Text("Add recipes manually or import one from a URL to start planning meals.")
                    } actions: {
                        zoomTransitionSource(id: .addRecipeEmptyState) {
                            Button("Add Recipe") {
                                addRecipeTransitionSource = .addRecipeEmptyState
                                showingAddRecipe = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(emptyStateInsets)
                } else if filteredRecipes.isEmpty {
                    ContentUnavailableView {
                        Label("No Recipes Found", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try another search, clear the current filters, or add a new recipe.")
                    } actions: {
                        zoomTransitionSource(id: .addRecipeFilteredEmptyState) {
                            Button("Add Recipe") {
                                addRecipeTransitionSource = .addRecipeFilteredEmptyState
                                showingAddRecipe = true
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button("Show All Recipes") {
                            searchText = ""
                            selectedMealTypeFilterID = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(emptyStateInsets)
                }

                ForEach(filteredRecipes) { recipe in
                    NavigationLink(value: recipe.id) {
                        HStack(spacing: 12) {
                            RecipeThumbnailView(photoData: recipe.photoData)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name)
                                
                                Text(recipe.listSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                RecipeListRatingStars(rating: recipe.rating)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .navigationDestination(for: UUID.self) { recipeID in
                recipeDestination(for: recipeID)
            }
            .listStyle(.plain)
            .navigationTitle("Recipes")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search name or meal type"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterAndSortMenu
                }
                
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                
                ToolbarItem(placement: .topBarTrailing) {
                    zoomTransitionSource(id: .addRecipeToolbar) {
                        Menu {
                            Button {
                                addRecipeTransitionSource = .addRecipeToolbar
                                showingAddRecipe = true
                            } label: {
                                Label("Add Manually", systemImage: "square.and.pencil")
                            }

                            Button {
                                showingImportRecipeAlert = true
                            } label: {
                                Label("Add from URL", systemImage: "link.badge.plus")
                            }
                            .disabled(isImportingRecipe)
                        } label: {
                            Label("Add Recipe", systemImage: "plus")
                        }
                    }
                }
                
            }
            .sheet(isPresented: $showingAddRecipe, onDismiss: openPendingCreatedRecipeIfNeeded) {
                zoomTransitionDestination(id: addRecipeTransitionSource) {
                    NavigationStack {
                        RecipeFormView { recipeID in
                            pendingCreatedRecipeID = recipeID
                        }
                    }
                }
            }
            .alert("Import Recipe", isPresented: $showingImportRecipeAlert) {
                TextField("https://example.com/recipe", text: $importURLText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Cancel", role: .cancel) {}

                Button("Paste from Clipboard") {
                    pasteRecipeURLFromClipboard()
                }
                .disabled(isImportingRecipe)

                Button("Import") {
                    importRecipeFromURL()
                }
                .disabled(importURL == nil || isImportingRecipe)
            } message: {
                Text("Paste a recipe URL.")
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "The recipe could not be imported.")
            }
            .onDisappear {
                runningImportTask?.cancel()
            }
            .onAppear {
                openSelectedRecipeIfNeeded()
            }
            .onChange(of: selectedRecipeID) { _, _ in
                openSelectedRecipeIfNeeded()
            }
        }
    }

    private var emptyStateInsets: EdgeInsets {
        EdgeInsets(top: 56, leading: 20, bottom: 56, trailing: 20)
    }

    private var filterAndSortMenu: some View {
        Menu {
            Section("Filter") {
                Picker(selectedMealTypeFilterTitle, selection: $selectedMealTypeFilterID) {
                    Text("All").tag(nil as UUID?)

                    ForEach(mealTypes) { mealType in
                        Text(mealType.name).tag(Optional(mealType.id))
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Order") {
                Picker(sortMode.title, selection: $sortMode) {
                    Text("by Name").tag(RecipeListSortMode.name)
                    Text("by Rating").tag(RecipeListSortMode.rating)
                }
                .pickerStyle(.menu)
            }

        } label: {
            Label(
                "Filter and Sort",
                systemImage: selectedMealTypeFilterID == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }

    @ViewBuilder
    private func recipeDestination(for recipeID: UUID) -> some View {
        if let recipe = recipes.first(where: { $0.id == recipeID }) {
            RecipeDetailView(
                recipe: recipe,
                onOpenThisWeekCalendar: onOpenThisWeekCalendar
            )
        } else {
            Text("Recipe not found.")
                .foregroundStyle(.secondary)
                .navigationTitle("Recipe")
        }
    }

    private func openSelectedRecipeIfNeeded() {
        guard let selectedRecipeID else { return }

        navigationPath = NavigationPath()
        navigationPath.append(selectedRecipeID)
        self.selectedRecipeID = nil
    }

    private func openPendingCreatedRecipeIfNeeded() {
        guard let pendingCreatedRecipeID else { return }

        navigationPath = NavigationPath()
        navigationPath.append(pendingCreatedRecipeID)
        self.pendingCreatedRecipeID = nil
    }

    private func importRecipeFromURL() {
        importRecipe(from: importURL)
    }

    private func pasteRecipeURLFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string,
              let clipboardURL = recipeURL(from: clipboardText) else {
            importErrorMessage = "The clipboard does not contain a recipe URL."
            showingImportError = true
            return
        }

        importURLText = clipboardText
        importRecipe(from: clipboardURL)
    }

    private func importRecipe(from importURL: URL?) {
        guard let importURL else { return }

        runningImportTask?.cancel()
        isImportingRecipe = true
        importErrorMessage = nil

        runningImportTask = Task { @MainActor in
            defer {
                isImportingRecipe = false
            }

            do {
                _ = try await RecipeURLRecipeImporter.importRecipe(
                    from: importURL,
                    in: modelContext
                )
                importURLText = ""
                IngredientEnrichmentScheduler.schedulePendingIngredientEnrichment(
                    in: modelContext
                )
            } catch {
                guard !Task.isCancelled else { return }
                importErrorMessage = localizedMessage(for: error)
                showingImportError = true
            }
        }
    }

    private func localizedMessage(for error: Error) -> String {
        if let error = error as? LocalizedError, let message = error.errorDescription {
            return message
        }

        return error.localizedDescription
    }

    private func deleteRecipes(at offsets: IndexSet) {
        let deletedRecipes = offsets.map { filteredRecipes[$0] }

        for recipe in deletedRecipes {
            for plannedMeal in recipe.plannedMeals ?? [] {
                modelContext.delete(plannedMeal)
            }

            modelContext.delete(recipe)
        }
    }
}

private enum RecipeListSortMode: Hashable {
    case name
    case rating

    var title: String {
        switch self {
        case .name:
            "by Name"
        case .rating:
            "by Rating"
        }
    }

    func sort(_ recipes: [Recipe]) -> [Recipe] {
        switch self {
        case .name:
            recipes.sorted(by: sortByName)
        case .rating:
            recipes.sorted { lhs, rhs in
                if lhs.rating != rhs.rating {
                    return lhs.rating > rhs.rating
                }

                return sortByName(lhs, rhs)
            }
        }
    }

    private func sortByName(_ lhs: Recipe, _ rhs: Recipe) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private struct RecipeListRatingStars: View {
    let rating: Int

    private var clampedRating: Int {
        min(max(rating, 0), 5)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= clampedRating ? "star.fill" : "star")
            }
        }
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundStyle(.yellow)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch clampedRating {
        case 1:
            "1 star"
        default:
            "\(clampedRating) stars"
        }
    }
}

private extension Recipe {
    var listSubtitle: String {
        let ingredientDescription = "\(ingredientLines?.count ?? 0) ingredients"
        guard let mealTypeName = mealType?.name, !mealTypeName.isEmpty else {
            return ingredientDescription
        }

        return "\(mealTypeName) | \(ingredientDescription)"
    }
}

#Preview("Recipes") {
    let previewData = PreviewData()

    RecipesView()
        .modelContainer(previewData.container)
}

#Preview("Recipes Empty") {
    let previewData = EmptyPreviewData()

    RecipesView()
        .modelContainer(previewData.container)
}
