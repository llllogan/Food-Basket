//
//  RecipeFormView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealType.name) private var mealTypes: [MealType]

    let recipe: Recipe?
    let onCreateRecipe: (UUID) -> Void
    @State private var name: String
    @State private var method: String
    @State private var cookingTimeMinutes: Int
    @State private var serves: Int
    @State private var selectedMealTypeID: UUID?
    @State private var newMealTypeName = ""
    @State private var showingNewMealTypeAlert = false
    @State private var locallyCreatedMealTypes: [MealType] = []
    @State private var didFinish = false

    init(
        recipe: Recipe? = nil,
        onCreateRecipe: @escaping (UUID) -> Void = { _ in }
    ) {
        self.recipe = recipe
        self.onCreateRecipe = onCreateRecipe
        _name = State(initialValue: recipe?.name ?? "")
        _method = State(initialValue: recipe?.method ?? "")
        _cookingTimeMinutes = State(initialValue: recipe?.cookingTimeMinutes ?? 0)
        _serves = State(initialValue: recipe?.serves ?? 0)
        _selectedMealTypeID = State(initialValue: recipe?.mealType?.id)
    }

    private var mealTypeSelection: Binding<UUID?> {
        Binding {
            selectedMealTypeID
        } set: { newValue in
            selectedMealTypeID = newValue
            cleanupTemporaryMealTypes(keeping: newValue)
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)

                Picker("Meal Type", selection: mealTypeSelection) {
                    Text("None").tag(nil as UUID?)

                    ForEach(mealTypes, id: \.id) { mealType in
                        Text(mealType.name).tag(mealType.id as UUID?)
                    }
                }

                Button {
                    newMealTypeName = ""
                    showingNewMealTypeAlert = true
                } label: {
                    Text("New Meal Type")
                }
            }
            
            Section {
                TextField("Cooking time (minutes)", value: $cookingTimeMinutes, format: .number)
                    .keyboardType(.numberPad)
            } header: {
                Text("Cooking time (minutes)")
            }
            
            Section("Serves") {
                TextField("Serves", value: $serves, format: .number)
                    .keyboardType(.numberPad)
            }

            Section("Method") {
                TextEditor(text: $method)
                    .frame(minHeight: 180)
            }
        }
        .navigationTitle(recipe == nil ? "New Recipe" : "Edit Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    cancel()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("New Meal Type", isPresented: $showingNewMealTypeAlert) {
            TextField("Meal type name", text: $newMealTypeName)

            Button("Add") {
                createMealTypeFromAlert()
            }
            .disabled(newMealTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Cancel", role: .cancel) {}
        }
        .onDisappear {
            guard !didFinish else { return }
            cleanupTemporaryMealTypes(keeping: nil)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var mealType = mealTypes.first { $0.id == selectedMealTypeID }
        mealType = mealType ?? locallyCreatedMealTypes.first { $0.id == selectedMealTypeID }

        if let recipe {
            recipe.name = trimmedName
            recipe.method = method.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.cookingTimeMinutes = cookingTimeMinutes
            recipe.serves = serves
            recipe.mealType = mealType
        } else {
            let newRecipe = Recipe(
                name: trimmedName,
                method: method.trimmingCharacters(in: .whitespacesAndNewlines),
                cookingTimeMinutes: cookingTimeMinutes,
                serves: serves,
                mealType: mealType
            )
            modelContext.insert(newRecipe)
            onCreateRecipe(newRecipe.id)
        }

        cleanupTemporaryMealTypes(keeping: mealType?.id)
        locallyCreatedMealTypes = []
        didFinish = true
        dismiss()
    }

    private func cancel() {
        cleanupTemporaryMealTypes(keeping: nil)
        didFinish = true
        dismiss()
    }

    private func createMealTypeFromAlert() {
        let normalizedName = newMealTypeName.normalizedLookupValue
        guard !normalizedName.isEmpty else { return }

        let existingMealType = mealTypes.first {
            $0.normalizedName == normalizedName
        } ?? locallyCreatedMealTypes.first {
            $0.normalizedName == normalizedName
        }

        let mealType: MealType
        if let existingMealType {
            mealType = existingMealType
        } else {
            mealType = MealType(
                name: newMealTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(mealType)
            locallyCreatedMealTypes.append(mealType)
        }

        selectedMealTypeID = mealType.id
        cleanupTemporaryMealTypes(keeping: mealType.id)
        try? modelContext.save()
    }

    private func cleanupTemporaryMealTypes(keeping mealTypeID: UUID?) {
        locallyCreatedMealTypes.removeAll { mealType in
            guard mealType.id != mealTypeID else { return false }

            if mealType.recipes?.isEmpty ?? true {
                modelContext.delete(mealType)
            }

            if selectedMealTypeID == mealType.id {
                selectedMealTypeID = nil
            }

            return true
        }

        try? modelContext.save()
    }
}

#Preview("New Recipe") {
    let previewData = PreviewData()

    NavigationStack {
        RecipeFormView()
    }
    .modelContainer(previewData.container)
}

#Preview("Edit Recipe") {
    let previewData = PreviewData()

    NavigationStack {
        RecipeFormView(recipe: previewData.recipe)
    }
    .modelContainer(previewData.container)
}
