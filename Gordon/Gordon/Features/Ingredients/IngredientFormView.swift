//
//  IngredientFormView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct IngredientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]

    let onSave: ((Ingredient) -> Void)?

    @State private var name = ""
    @State private var defaultQuantity = 1.0
    @State private var selectedCategoryID: UUID?
    @State private var selectedUnitID: UUID?
    @State private var newCategoryName = ""
    @State private var newUnitName = ""
    @State private var newUnitSymbol = ""

    init(onSave: ((Ingredient) -> Void)? = nil) {
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Ingredient") {
                TextField("Name", text: $name)
                TextField("Default quantity", value: $defaultQuantity, format: .number)
                    .keyboardType(.decimalPad)
            }

            Section("Category") {
                Picker("Existing category", selection: $selectedCategoryID) {
                    Text("None").tag(nil as UUID?)

                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }

                TextField("Or create a category", text: $newCategoryName)
            }

            Section("Unit") {
                Picker("Existing unit", selection: $selectedUnitID) {
                    Text("None").tag(nil as UUID?)

                    ForEach(units) { unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(unit.id as UUID?)
                    }
                }

                TextField("Or create a unit", text: $newUnitName)
                TextField("New unit symbol", text: $newUnitSymbol)
            }
        }
        .navigationTitle("New Ingredient")
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
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    defaultQuantity <= 0
                )
            }
        }
        .task {
            selectDefaultUnitIfNeeded()
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingIngredient = ingredients.first(where: {
            $0.normalizedName == trimmedName.normalizedLookupValue
        }) {
            onSave?(existingIngredient)
            dismiss()
            return
        }

        var category = categories.first { $0.id == selectedCategoryID }
        if !newCategoryName.normalizedLookupValue.isEmpty {
            category = SeedData.category(
                named: newCategoryName,
                existing: categories,
                in: modelContext
            )
        }

        var unit = units.first { $0.id == selectedUnitID }
        if !newUnitName.normalizedLookupValue.isEmpty {
            unit = SeedData.unit(
                named: newUnitName,
                symbol: newUnitSymbol,
                existing: units,
                in: modelContext
            )
        }

        let ingredient = Ingredient(
            name: trimmedName,
            defaultQuantity: defaultQuantity,
            category: category,
            unit: unit
        )
        modelContext.insert(ingredient)
        generateImage(for: ingredient)
        onSave?(ingredient)
        dismiss()
    }

    private func selectDefaultUnitIfNeeded() {
        guard selectedUnitID == nil else { return }
        selectedUnitID = units.first(where: { $0.normalizedName == "each" })?.id
    }

    private func generateImage(for ingredient: Ingredient) {
        Task { @MainActor in
            guard let photoData = await IngredientImageGenerator.generateImageData(
                for: ingredient.name
            ) else {
                return
            }

            ingredient.photoData = photoData
            try? modelContext.save()
        }
    }
}

#Preview("New Ingredient") {
    let previewData = PreviewData()

    NavigationStack {
        IngredientFormView()
    }
    .modelContainer(previewData.container)
}
