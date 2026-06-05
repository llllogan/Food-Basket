//
//  RecipesView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

struct RecipesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var showingAddRecipe = false
    @State private var searchText = ""

    private var filteredRecipes: [Recipe] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return recipes }

        return recipes.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if recipes.isEmpty {
                    Text("Add a recipe to get started.")
                        .foregroundStyle(.secondary)
                } else if filteredRecipes.isEmpty {
                    Text("No recipes found.")
                        .foregroundStyle(.secondary)
                }

                ForEach(filteredRecipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        HStack(spacing: 12) {
                            RecipeThumbnailView(photoData: recipe.photoData)

                            VStack(alignment: .leading) {
                                Text(recipe.name)
                                Text("\(recipe.ingredientLines?.count ?? 0) ingredients")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .listStyle(.plain)
            .navigationTitle("Recipes")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search recipes"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddRecipe = true
                    } label: {
                        Label("Add Recipe", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                NavigationStack {
                    RecipeFormView()
                }
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        let deletedRecipes = offsets.map { filteredRecipes[$0] }

        for recipe in deletedRecipes {
            for plannedMeal in recipe.plannedMeals ?? [] {
                modelContext.delete(plannedMeal)
            }

            modelContext.delete(recipe)
        }
    }
}

#Preview("Recipes") {
    let previewData = PreviewData()

    RecipesView()
        .modelContainer(previewData.container)
}
