//
//  RecipeFormView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let recipe: Recipe?
    @State private var name: String
    @State private var method: String
    @State private var cookingTimeMinutes: Int
    @State private var serves: Int

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _name = State(initialValue: recipe?.name ?? "")
        _method = State(initialValue: recipe?.method ?? "")
        _cookingTimeMinutes = State(initialValue: recipe?.cookingTimeMinutes ?? 0)
        _serves = State(initialValue: recipe?.serves ?? 0)
    }

    var body: some View {
        Form {
            Section("Recipe") {
                TextField("Name", text: $name)
                TextField("Cooking time (minutes)", value: $cookingTimeMinutes, format: .number)
                    .keyboardType(.numberPad)
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
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let recipe {
            recipe.name = trimmedName
            recipe.method = method.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.cookingTimeMinutes = cookingTimeMinutes
            recipe.serves = serves
        } else {
            modelContext.insert(
                Recipe(
                    name: trimmedName,
                    method: method.trimmingCharacters(in: .whitespacesAndNewlines),
                    cookingTimeMinutes: cookingTimeMinutes,
                    serves: serves
                )
            )
        }

        dismiss()
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
