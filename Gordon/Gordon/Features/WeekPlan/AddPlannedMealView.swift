//
//  AddPlannedMealView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct AddPlannedMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    let weekStarting: Date
    @State private var searchText = ""

    private var filteredRecipes: [Recipe] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return recipes }

        return recipes.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        List {
            Section("Recipes") {
                if recipes.isEmpty {
                    Text("Create a recipe before adding a meal.")
                        .foregroundStyle(.secondary)
                } else if filteredRecipes.isEmpty {
                    Text("No recipes found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredRecipes) { recipe in
                        NavigationLink {
                            AddPlannedMealAmountView(weekStarting: weekStarting, recipe: recipe) {
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                RecipeThumbnailView(photoData: recipe.photoData)

                                Text(recipe.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Meal")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search recipes"
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview("Add Meal") {
    let previewData = PreviewData()

    NavigationStack {
        AddPlannedMealView(
            weekStarting: Calendar.current.startOfWeek(containing: Date())
        )
    }
    .modelContainer(previewData.container)
}
