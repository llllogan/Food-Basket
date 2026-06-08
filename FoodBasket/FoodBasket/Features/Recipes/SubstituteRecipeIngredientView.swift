//
//  SubstituteRecipeIngredientView.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import SwiftData
import SwiftUI

struct SubstituteRecipeIngredientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]

    let line: RecipeIngredient
    @State private var searchText = ""

    private var filteredIngredients: [Ingredient] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return ingredients }

        return ingredients.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        List {
            Section("Current") {
                HStack(spacing: 12) {
                    IngredientThumbnailView(photoData: line.ingredient?.photoData)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.ingredient?.name ?? "Deleted ingredient")
                            .foregroundStyle(.primary)

                        Text(line.formattedSubstitutionDetails)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Substitute With") {
                if ingredients.isEmpty {
                    Text("No ingredients available.")
                        .foregroundStyle(.secondary)
                } else if filteredIngredients.isEmpty {
                    Text("No ingredients found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredIngredients) { ingredient in
                        Button {
                            substitute(with: ingredient)
                        } label: {
                            HStack(spacing: 12) {
                                IngredientThumbnailView(photoData: ingredient.photoData)

                                Text(ingredient.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if ingredient.id == line.ingredient?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Substitute Ingredient")
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
        }
    }

    private func substitute(with ingredient: Ingredient) {
        line.ingredient = ingredient
        try? modelContext.save()
        dismiss()
    }
}

private extension RecipeIngredient {
    var formattedSubstitutionDetails: String {
        let quantityText = quantity.formatted(.number.precision(.fractionLength(0...2)))
        let unitText = unit?.symbol ?? ""
        let amountText = unitText.isEmpty ? quantityText : "\(quantityText) \(unitText)"
        let trimmedPreparationMethod = preparationMethod.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPreparationMethod.isEmpty else {
            return amountText
        }

        return "\(amountText) - \(trimmedPreparationMethod)"
    }
}

#Preview("Substitute Recipe Ingredient") {
    let previewData = PreviewData()

    NavigationStack {
        SubstituteRecipeIngredientView(line: previewData.recipe.ingredientLines?.first ?? RecipeIngredient(quantity: 1))
    }
    .modelContainer(previewData.container)
}
