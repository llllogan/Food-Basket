//
//  RecipesView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData
import UIKit

struct RecipesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var showingAddRecipe = false
    @State private var showingImportRecipeAlert = false
    @State private var importURLText = ""
    @State private var isImportingRecipe = false
    @State private var importErrorMessage: String?
    @State private var showingImportError = false
    @State private var runningImportTask: Task<Void, Never>?
    @State private var searchText = ""

    private var importURL: URL? {
        recipeURL(from: importURLText)
    }

    private func recipeURL(from text: String) -> URL? {
        let trimmedURL = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }

        if trimmedURL.contains("://") {
            return URL(string: trimmedURL)
        }

        return URL(string: "https://\(trimmedURL)")
    }

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
                    Menu {
                        Button {
                            showingAddRecipe = true
                        } label: {
                            Label("Add Manually", systemImage: "square.and.pencil")
                        }

                        Button {
                            showingImportRecipeAlert = true
                        } label: {
                            Label("Add from URL", systemImage: "link.badge.plus")
                        }
                        .disabled(isImportingRecipe)
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
            .alert("Import Recipe", isPresented: $showingImportRecipeAlert) {
                TextField("https://example.com/recipe", text: $importURLText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Cancel", role: .cancel) {}

                Button("Paste from Clipboard") {
                    pasteRecipeURLFromClipboard()
                }
                .disabled(isImportingRecipe)

                Button("Import") {
                    importRecipeFromURL()
                }
                .disabled(importURL == nil || isImportingRecipe)
            } message: {
                Text("Paste a recipe URL.")
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "The recipe could not be imported.")
            }
            .onDisappear {
                runningImportTask?.cancel()
            }
        }
    }

    private func importRecipeFromURL() {
        importRecipe(from: importURL)
    }

    private func pasteRecipeURLFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string,
              let clipboardURL = recipeURL(from: clipboardText) else {
            importErrorMessage = "The clipboard does not contain a recipe URL."
            showingImportError = true
            return
        }

        importURLText = clipboardText
        importRecipe(from: clipboardURL)
    }

    private func importRecipe(from importURL: URL?) {
        guard let importURL else { return }

        runningImportTask?.cancel()
        isImportingRecipe = true
        importErrorMessage = nil

        runningImportTask = Task { @MainActor in
            defer {
                isImportingRecipe = false
            }

            do {
                _ = try await RecipeURLRecipeImporter.importRecipe(
                    from: importURL,
                    in: modelContext
                )
                importURLText = ""
                IngredientEnrichmentScheduler.schedulePendingIngredientEnrichment(
                    in: modelContext
                )
            } catch {
                guard !Task.isCancelled else { return }
                importErrorMessage = localizedMessage(for: error)
                showingImportError = true
            }
        }
    }

    private func localizedMessage(for error: Error) -> String {
        if let error = error as? LocalizedError, let message = error.errorDescription {
            return message
        }

        return error.localizedDescription
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
