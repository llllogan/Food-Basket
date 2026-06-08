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
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]

    let recipe: Recipe
    let ingredient: Ingredient
    let onAdd: () -> Void
    @State private var quantity: Double
    @State private var selectedUnitID: UUID?
    @State private var preparationMethod = ""
    @State private var newUnitName = ""
    @State private var newUnitSymbol = ""
    @State private var showingNewUnitAlert = false
    @State private var locallyCreatedUnits: [MeasurementUnit] = []
    @State private var didFinish = false

    init(recipe: Recipe, ingredient: Ingredient, onAdd: @escaping () -> Void) {
        self.recipe = recipe
        self.ingredient = ingredient
        self.onAdd = onAdd
        _quantity = State(initialValue: 1)
    }

    private var unitSelection: Binding<UUID?> {
        Binding {
            selectedUnitID
        } set: { newValue in
            selectedUnitID = newValue
            cleanupTemporaryUnits(keeping: newValue)
        }
    }

    var body: some View {
        Form {
            Section("Ingredient") {
                LabeledContent("Name", value: ingredient.name)
            }

            Section("Amount") {
                TextField("Quantity", value: $quantity, format: .number)
                    .keyboardType(.decimalPad)

                Picker("Unit", selection: unitSelection) {
                    Text("Select Unit").tag(nil as UUID?)

                    ForEach(units) { unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(unit.id as UUID?)
                    }
                }

                Button {
                    newUnitName = ""
                    newUnitSymbol = ""
                    showingNewUnitAlert = true
                } label: {
                    Text("New Unit")
                }
            }

            Section("Preparation Method") {
                TextField("Diced, shredded, drained", text: $preparationMethod, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Select Amount")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addIngredient()
                }
                .disabled(quantity <= 0 || selectedUnitID == nil)
            }
        }
        .task {
            selectDefaultUnitIfNeeded()
        }
        .alert("New Unit", isPresented: $showingNewUnitAlert) {
            TextField("Unit name", text: $newUnitName)
            TextField("Symbol (mL, tsp)", text: $newUnitSymbol)

            Button("Add") {
                createUnitFromAlert()
            }
            .disabled(newUnitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Cancel", role: .cancel) {}
        }
        .onDisappear {
            guard !didFinish else { return }
            cleanupTemporaryUnits(keeping: nil)
        }
    }

    private func addIngredient() {
        var unit = units.first { $0.id == selectedUnitID }
        unit = unit ?? locallyCreatedUnits.first { $0.id == selectedUnitID }
        guard let unit else { return }

        let line = RecipeIngredient(
            quantity: quantity,
            preparationMethod: preparationMethod.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: recipe.ingredientLines?.count ?? 0,
            ingredient: ingredient,
            unit: unit
        )
        recipe.ingredientLines = (recipe.ingredientLines ?? []) + [line]
        modelContext.insert(line)
        cleanupTemporaryUnits(keeping: unit.id)
        locallyCreatedUnits = []
        didFinish = true
        onAdd()
    }

    private func selectDefaultUnitIfNeeded() {
        guard selectedUnitID == nil else { return }
        selectedUnitID = units.first(where: { $0.normalizedName == "each" })?.id ?? units.first?.id
    }

    private func createUnitFromAlert() {
        let normalizedName = newUnitName.normalizedLookupValue
        guard !normalizedName.isEmpty else { return }

        let existingUnit = units.first {
            $0.normalizedName == normalizedName
        } ?? locallyCreatedUnits.first {
            $0.normalizedName == normalizedName
        }

        let unit: MeasurementUnit
        if let existingUnit {
            unit = existingUnit
        } else {
            let trimmedName = newUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSymbol = newUnitSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
            unit = MeasurementUnit(
                name: trimmedName,
                symbol: trimmedSymbol.isEmpty ? trimmedName : trimmedSymbol
            )
            modelContext.insert(unit)
            locallyCreatedUnits.append(unit)
        }

        selectedUnitID = unit.id
        cleanupTemporaryUnits(keeping: unit.id)
        try? modelContext.save()
    }

    private func cleanupTemporaryUnits(keeping unitID: UUID?) {
        locallyCreatedUnits.removeAll { unit in
            guard unit.id != unitID else { return false }

            if unit.recipeLines?.isEmpty ?? true {
                modelContext.delete(unit)
            }

            if selectedUnitID == unit.id {
                selectedUnitID = nil
            }

            return true
        }

        try? modelContext.save()
    }
}
