//
//  IngredientsView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

struct IngredientsView: View {
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @State private var showingAddIngredient = false

    var body: some View {
        NavigationStack {
            List {
                if ingredients.isEmpty {
                    Text("Add ingredients as you create recipes.")
                        .foregroundStyle(.secondary)
                }

                ForEach(ingredients) { ingredient in
                    NavigationLink {
                        IngredientDetailView(ingredient: ingredient)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(ingredient.name)
                            Text(ingredient.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Ingredients")
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
}

struct IngredientDetailView: View {
    @Bindable var ingredient: Ingredient
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]

    var body: some View {
        Form {
            Section("Ingredient") {
                TextField("Name", text: $ingredient.name)
                    .onChange(of: ingredient.name) {
                        ingredient.normalizedName = ingredient.name.normalizedLookupValue
                    }

                TextField("Default quantity", value: $ingredient.defaultQuantity, format: .number)
                    .keyboardType(.decimalPad)
            }

            Section("Category") {
                Picker("Category", selection: $ingredient.category) {
                    Text("None").tag(nil as IngredientCategory?)

                    ForEach(categories) { category in
                        Text(category.name).tag(category as IngredientCategory?)
                    }
                }
            }

            Section("Unit") {
                Picker("Unit", selection: $ingredient.unit) {
                    Text("None").tag(nil as MeasurementUnit?)

                    ForEach(units) { unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(unit as MeasurementUnit?)
                    }
                }
            }
        }
        .navigationTitle(ingredient.name)
    }
}

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
        onSave?(ingredient)
        dismiss()
    }

    private func selectDefaultUnitIfNeeded() {
        guard selectedUnitID == nil else { return }
        selectedUnitID = units.first(where: { $0.normalizedName == "each" })?.id
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
