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
    @State private var showingAddIngredient = false
    @State private var searchText = ""

    private var filteredIngredients: [Ingredient] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return ingredients }

        return ingredients.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
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
                        Text("Try another search, show all ingredients, or add a new ingredient.")
                    } actions: {
                        Button("Add Ingredient") {
                            showingAddIngredient = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Show All Ingredients") {
                            searchText = ""
                        }
                        .buttonStyle(.bordered)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(emptyStateInsets)
                }

                ForEach(filteredIngredients) { ingredient in
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
                .onDelete(perform: deleteIngredients)
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

    private func deleteIngredients(at offsets: IndexSet) {
        let deletedIngredients = offsets.map { filteredIngredients[$0] }

        for ingredient in deletedIngredients {
            for recipeLine in ingredient.recipeLines ?? [] {
                modelContext.delete(recipeLine)
            }

            modelContext.delete(ingredient)
        }
    }
}

private extension Ingredient {
    var subtitle: String {
        let quantity = defaultQuantity.formatted(.number.precision(.fractionLength(0...2)))
        let unitDescription = unit?.symbol ?? "no unit"
        let categoryDescription = category?.name ?? "No category"
        return "\(quantity) \(unitDescription) | \(categoryDescription)"
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
