//
//  IngredientsView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

struct IngredientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @State private var showingAddIngredient = false
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

    var body: some View {
        NavigationStack {
            List {
                if ingredients.isEmpty {
                    ContentUnavailableView {
                        Label("No Ingredients Yet", systemImage: "carrot")
                    } description: {
                        Text("Add ingredients directly, or they will appear here as you create recipes.")
                    } actions: {
                        Button("Add Ingredient") {
                            showingAddIngredient = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(emptyStateInsets)
                } else if filteredIngredients.isEmpty {
                    ContentUnavailableView {
                        Label("No Ingredients Found", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try another search, clear the current filters, or add a new ingredient.")
                    } actions: {
                        Button("Add Ingredient") {
                            showingAddIngredient = true
                        }
                        .buttonStyle(.borderedProminent)

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
                    Button {
                        showingAddIngredient = true
                    } label: {
                        Label("Add Ingredient", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddIngredient) {
                NavigationStack {
                    IngredientFormView()
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
                Button {
                    organiseMode = .name
                } label: {
                    filterMenuLabel(
                        "by Name",
                        isSelected: organiseMode == .name
                    )
                }

                Button {
                    organiseMode = .category
                } label: {
                    filterMenuLabel(
                        "by Category",
                        isSelected: organiseMode == .category
                    )
                }
            }

            Section("Recipes") {
                Button {
                    recipeFilter = .all
                } label: {
                    filterMenuLabel(
                        "All Ingredients",
                        isSelected: recipeFilter == .all
                    )
                }

                Button {
                    recipeFilter = .withoutRecipes
                } label: {
                    filterMenuLabel(
                        "Without Recipes",
                        isSelected: recipeFilter == .withoutRecipes
                    )
                }

                Button {
                    recipeFilter = .withRecipes
                } label: {
                    filterMenuLabel(
                        "With Recipes",
                        isSelected: recipeFilter == .withRecipes
                    )
                }
            }
            
            Section("Filter") {
                Button {
                    selectedCategoryFilterID = nil
                } label: {
                    filterMenuLabel(
                        "All",
                        isSelected: selectedCategoryFilterID == nil
                    )
                }

                ForEach(categories) { category in
                    Button {
                        selectedCategoryFilterID = category.id
                    } label: {
                        filterMenuLabel(
                            category.name,
                            isSelected: selectedCategoryFilterID == category.id
                        )
                    }
                }
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

    @ViewBuilder
    private func filterMenuLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
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

private enum IngredientListOrganiseMode: String {
    case name
    case category

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

private enum IngredientRecipeFilter {
    case all
    case withoutRecipes
    case withRecipes

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
