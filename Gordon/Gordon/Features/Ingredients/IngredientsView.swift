//
//  IngredientsView.swift
//  Gordon
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
                    Text("Add ingredients as you create recipes.")
                        .foregroundStyle(.secondary)
                } else if filteredIngredients.isEmpty {
                    Text("No ingredients found.")
                        .foregroundStyle(.secondary)
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

    private func deleteIngredients(at offsets: IndexSet) {
        let deletedIngredients = offsets.map { filteredIngredients[$0] }

        for ingredient in deletedIngredients {
            for recipeLine in ingredient.recipeLines {
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
