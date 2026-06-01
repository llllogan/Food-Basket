//
//  AddIngredientAmountView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct AddIngredientAmountView: View {
    @Environment(\.modelContext) private var modelContext

    let recipe: Recipe
    let ingredient: Ingredient
    let onAdd: () -> Void
    @State private var quantity: Double

    init(recipe: Recipe, ingredient: Ingredient, onAdd: @escaping () -> Void) {
        self.recipe = recipe
        self.ingredient = ingredient
        self.onAdd = onAdd
        _quantity = State(initialValue: ingredient.defaultQuantity)
    }

    var body: some View {
        Form {
            Section("Ingredient") {
                LabeledContent("Name", value: ingredient.name)
                LabeledContent("Unit", value: ingredient.unit?.symbol ?? "No unit")
            }

            Section("Amount") {
                TextField("Quantity", value: $quantity, format: .number)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Select Amount")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addIngredient()
                }
                .disabled(quantity <= 0)
            }
        }
    }

    private func addIngredient() {
        let line = RecipeIngredient(
            quantity: quantity,
            sortOrder: recipe.ingredientLines?.count ?? 0,
            ingredient: ingredient
        )
        recipe.ingredientLines = (recipe.ingredientLines ?? []) + [line]
        modelContext.insert(line)
        onAdd()
    }
}
