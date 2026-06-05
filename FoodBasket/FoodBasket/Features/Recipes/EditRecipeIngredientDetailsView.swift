//
//  EditRecipeIngredientDetailsView.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import SwiftData
import SwiftUI

struct EditRecipeIngredientDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let line: RecipeIngredient
    let onDelete: () -> Void

    @State private var quantity: Double
    @State private var preparationMethod: String

    init(line: RecipeIngredient, onDelete: @escaping () -> Void) {
        self.line = line
        self.onDelete = onDelete
        _quantity = State(initialValue: line.quantity)
        _preparationMethod = State(initialValue: line.preparationMethod)
    }

    var body: some View {
        Form {
            Section("Ingredient") {
                LabeledContent("Name", value: line.ingredient?.name ?? "Deleted ingredient")
                LabeledContent("Unit", value: line.ingredient?.unit?.symbol ?? "No unit")
            }

            Section("Amount") {
                TextField("Quantity", value: $quantity, format: .number)
                    .keyboardType(.decimalPad)
            }

            Section("Preparation Instructions") {
                TextField("Diced, shredded, drained", text: $preparationMethod, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Edit Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(quantity <= 0)
            }

            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text("Remove from Recipe")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func save() {
        line.quantity = quantity
        line.preparationMethod = preparationMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }
}

#Preview("Edit Recipe Ingredient Details") {
    let previewData = PreviewData()

    NavigationStack {
        EditRecipeIngredientDetailsView(
            line: previewData.recipe.ingredientLines?.first ?? RecipeIngredient(quantity: 1),
            onDelete: {}
        )
    }
    .modelContainer(previewData.container)
}
