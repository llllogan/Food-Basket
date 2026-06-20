//
//  IngredientsView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

private enum IngredientListTransitionSource: Hashable {
    case addIngredientToolbar
    case addIngredientEmptyState
    case addIngredientFilteredEmptyState
}

struct IngredientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @Namespace private var ingredientListTransitionNamespace
    @State private var showingAddIngredient = false
    @State private var addIngredientTransitionSource: IngredientListTransitionSource = .addIngredientToolbar
    @State private var searchText = ""
    @State private var selectedCategoryFilterID: UUID?
    @State private var recipeFilter = IngredientRecipeFilter.all
    @AppStorage(IngredientListOrganiseDefaults.modeKey)
    private var organiseModeRawValue = IngredientListOrganiseMode.name.rawValue

    private var organiseMode: IngredientListOrganiseMode {
        get {
            IngredientListOrganiseMode(rawValue: organiseModeRawValue) ?? .name
        }
        nonmutating set {
            organiseModeRawValue = newValue.rawValue
        }
    }

    private var filteredIngredients: [Ingredient] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchMatchedIngredients: [Ingredient]

        if trimmedSearchText.isEmpty {
            searchMatchedIngredients = ingredients
        } else {
            searchMatchedIngredients = ingredients.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
            }
        }

        let categoryMatchedIngredients: [Ingredient]
        if let selectedCategoryFilterID {
            categoryMatchedIngredients = searchMatchedIngredients.filter {
                $0.category?.id == selectedCategoryFilterID
            }
        } else {
            categoryMatchedIngredients = searchMatchedIngredients
        }

        return categoryMatchedIngredients.filter {
            recipeFilter.includes($0)
        }
    }

    private var categorySections: [IngredientCategorySection] {
        let uncategorisedIngredients = filteredIngredients.filter {
            $0.category == nil
        }
        let uncategorisedSection = IngredientCategorySection(
            id: "uncategorised",
            title: "No category",
            ingredients: IngredientListOrganiseMode.sortedByName(uncategorisedIngredients)
        )

        let categorisedSections = categories.compactMap { category -> IngredientCategorySection? in
            let ingredients = filteredIngredients.filter {
                $0.category?.id == category.id
            }

            guard !ingredients.isEmpty else { return nil }

            return IngredientCategorySection(
                id: category.id.uuidString,
                title: category.name,
                ingredients: IngredientListOrganiseMode.sortedByName(ingredients)
            )
        }

        if uncategorisedSection.ingredients.isEmpty {
            return categorisedSections
        }

        return categorisedSections + [uncategorisedSection]
    }

    private var hasActiveFilters: Bool {
        selectedCategoryFilterID != nil || recipeFilter != .all
    }

    private var selectedCategoryFilterTitle: String {
        guard let selectedCategoryFilterID,
              let selectedCategory = categories.first(where: { $0.id == selectedCategoryFilterID }) else {
            return "All"
        }

        return selectedCategory.name
    }

    @ViewBuilder
    private func zoomTransitionSource<Content: View>(
        id: IngredientListTransitionSource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 18.0, *) {
            content()
                .matchedTransitionSource(id: id, in: ingredientListTransitionNamespace)
        } else {
            content()
        }
    }

    @ViewBuilder
    private func zoomTransitionDestination<Content: View>(
        id: IngredientListTransitionSource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 18.0, *) {
            content()
                .navigationTransition(.zoom(sourceID: id, in: ingredientListTransitionNamespace))
        } else {
            content()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if ingredients.isEmpty {
                    ContentUnavailableView {
                        Label("No Ingredients Yet", systemImage: "carrot")
                    } description: {
                        Text("Add ingredients directly, or they will appear here as you create recipes.")
                    } actions: {
                        zoomTransitionSource(id: .addIngredientEmptyState) {
                            Button("Add Ingredient") {
                                addIngredientTransitionSource = .addIngredientEmptyState
                                showingAddIngredient = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(emptyStateInsets)
                } else if filteredIngredients.isEmpty {
                    ContentUnavailableView {
                        Label("No Ingredients Found", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try another search, clear the current filters, or add a new ingredient.")
                    } actions: {
                        zoomTransitionSource(id: .addIngredientFilteredEmptyState) {
                            Button("Add Ingredient") {
                                addIngredientTransitionSource = .addIngredientFilteredEmptyState
                                showingAddIngredient = true
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button("Show All Ingredients") {
                            clearIngredientFilters()
                        }
                        .buttonStyle(.bordered)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(emptyStateInsets)
                }

                switch organiseMode {
                case .name:
                    ForEach(IngredientListOrganiseMode.sortedByName(filteredIngredients)) { ingredient in
                        ingredientRow(for: ingredient)
                    }
                    .onDelete { offsets in
                        deleteIngredients(at: offsets)
                    }
                case .category:
                    ForEach(categorySections) { section in
                        Section(section.title) {
                            ForEach(section.ingredients) { ingredient in
                                ingredientRow(for: ingredient)
                            }
                            .onDelete { offsets in
                                deleteIngredients(at: offsets, in: section.ingredients)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Ingredients")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search ingredients"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ingredientFilterMenu
                }

                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    zoomTransitionSource(id: .addIngredientToolbar) {
                        Button {
                            addIngredientTransitionSource = .addIngredientToolbar
                            showingAddIngredient = true
                        } label: {
                            Label("Add Ingredient", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddIngredient) {
                zoomTransitionDestination(id: addIngredientTransitionSource) {
                    NavigationStack {
                        IngredientFormView()
                    }
                }
            }
        }
    }

    private var emptyStateInsets: EdgeInsets {
        EdgeInsets(top: 56, leading: 20, bottom: 56, trailing: 20)
    }

    private var ingredientFilterMenu: some View {
        Menu {
            Section("Organise") {
                Picker(
                    organiseMode.title,
                    selection: Binding(
                        get: { organiseMode },
                        set: { organiseMode = $0 }
                    )
                ) {
                    Text("by Name").tag(IngredientListOrganiseMode.name)
                    Text("by Category").tag(IngredientListOrganiseMode.category)
                }
                .pickerStyle(.menu)
            }

            Section("Recipes") {
                Picker(recipeFilter.title, selection: $recipeFilter) {
                    Text("All Ingredients").tag(IngredientRecipeFilter.all)
                    Text("Without Recipes").tag(IngredientRecipeFilter.withoutRecipes)
                    Text("With Recipes").tag(IngredientRecipeFilter.withRecipes)
                }
                .pickerStyle(.menu)
            }
            
            Section("Filter") {
                Picker(selectedCategoryFilterTitle, selection: $selectedCategoryFilterID) {
                    Text("All").tag(nil as UUID?)

                    ForEach(categories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                .pickerStyle(.menu)
            }

        } label: {
            Label(
                "Filter Ingredients",
                systemImage: hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }

    private func ingredientRow(for ingredient: Ingredient) -> some View {
        NavigationLink {
            IngredientDetailView(ingredient: ingredient)
        } label: {
            HStack(spacing: 12) {
                IngredientThumbnailView(photoData: ingredient.photoData)

                VStack(alignment: .leading) {
                    Text(ingredient.name)
                    Text(ingredient.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func clearIngredientFilters() {
        searchText = ""
        selectedCategoryFilterID = nil
        recipeFilter = .all
    }

    private func deleteIngredients(at offsets: IndexSet) {
        let ingredientsByName = IngredientListOrganiseMode.sortedByName(filteredIngredients)
        deleteIngredients(offsets.map { ingredientsByName[$0] })
    }

    private func deleteIngredients(at offsets: IndexSet, in ingredients: [Ingredient]) {
        deleteIngredients(offsets.map { ingredients[$0] })
    }

    private func deleteIngredients(_ deletedIngredients: [Ingredient]) {
        for ingredient in deletedIngredients {
            for recipeLine in ingredient.recipeLines ?? [] {
                modelContext.delete(recipeLine)
            }

            modelContext.delete(ingredient)
        }
    }
}

private enum IngredientListOrganiseDefaults {
    static let modeKey = "ingredientListOrganiseMode"
}

private enum IngredientListOrganiseMode: String, Hashable {
    case name
    case category

    var title: String {
        switch self {
        case .name:
            "by Name"
        case .category:
            "by Category"
        }
    }

    nonisolated static func sortedByName(_ ingredients: [Ingredient]) -> [Ingredient] {
        ingredients.sorted(by: sortByName)
    }

    private nonisolated static func sortByName(_ lhs: Ingredient, _ rhs: Ingredient) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private struct IngredientCategorySection: Identifiable {
    let id: String
    let title: String
    let ingredients: [Ingredient]
}

private enum IngredientRecipeFilter: Hashable {
    case all
    case withoutRecipes
    case withRecipes

    var title: String {
        switch self {
        case .all:
            "All Ingredients"
        case .withoutRecipes:
            "Without Recipes"
        case .withRecipes:
            "With Recipes"
        }
    }

    func includes(_ ingredient: Ingredient) -> Bool {
        switch self {
        case .all:
            true
        case .withoutRecipes:
            !ingredient.isUsedInRecipe
        case .withRecipes:
            ingredient.isUsedInRecipe
        }
    }
}

private extension Ingredient {
    var subtitle: String {
        category?.name ?? "No category"
    }

    var isUsedInRecipe: Bool {
        (recipeLines ?? []).contains { $0.recipe != nil }
    }
}

#Preview("Ingredients") {
    let previewData = PreviewData()

    IngredientsView()
        .modelContainer(previewData.container)
}

#Preview("Ingredients Empty") {
    let previewData = EmptyPreviewData()

    IngredientsView()
        .modelContainer(previewData.container)
}
