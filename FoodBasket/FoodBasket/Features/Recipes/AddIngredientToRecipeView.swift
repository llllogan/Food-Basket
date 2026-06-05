//
//  AddIngredientToRecipeView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct AddIngredientToRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]

    let recipe: Recipe
    @State private var createdIngredientForAmount: Ingredient?
    @State private var showingCreatedIngredientAmount = false
    @State private var showingNewIngredient = false
    @State private var searchText = ""

    private var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredIngredients: [Ingredient] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return ingredients }

        return ingredients.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        List {
            Section("Ingredients") {
                if hasSearchText && filteredIngredients.isEmpty {
                    Button {
                        showNewIngredient()
                    } label: {
                        AddNewIngredientRowLabel()
                    }
                    .buttonStyle(.plain)
                } else if ingredients.isEmpty {
                    Text("Create your first ingredient.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredIngredients) { ingredient in
                        NavigationLink {
                            AddIngredientAmountView(recipe: recipe, ingredient: ingredient) {
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                IngredientThumbnailView(photoData: ingredient.photoData)

                                Text(ingredient.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search ingredients"
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button("Create New Ingredient") {
                    showNewIngredient()
                }
            }
        }
        .navigationDestination(isPresented: $showingCreatedIngredientAmount) {
            if let createdIngredientForAmount {
                AddIngredientAmountView(recipe: recipe, ingredient: createdIngredientForAmount) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingNewIngredient, onDismiss: {
            guard createdIngredientForAmount != nil else { return }
            showingCreatedIngredientAmount = true
        }) {
            NavigationStack {
                IngredientFormView { ingredient in
                    searchText = ""
                    createdIngredientForAmount = ingredient
                    showingNewIngredient = false
                }
            }
        }
    }

    private func showNewIngredient() {
        createdIngredientForAmount = nil
        showingNewIngredient = true
    }
}

private struct AddNewIngredientRowLabel: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color(uiColor: .tertiarySystemFill)

                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .accessibilityHidden(true)

            Text("Add new ingredient")
                .foregroundStyle(.primary)
        }
    }
}

#Preview("Add Ingredient to Recipe") {
    let previewData = PreviewData()

    NavigationStack {
        AddIngredientToRecipeView(recipe: previewData.recipe)
    }
    .modelContainer(previewData.container)
}
