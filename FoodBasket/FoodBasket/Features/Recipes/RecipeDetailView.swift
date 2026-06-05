//
//  RecipeDetailView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI
import UIKit

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe
    @State private var showingAddIngredient = false
    @State private var showingEditRecipe = false
    @State private var showingCamera = false
    @State private var showingCameraUnavailable = false
    @State private var editedIngredientLine: RecipeIngredient?
    @State private var substitutedIngredientLine: RecipeIngredient?

    private var ingredientLines: [RecipeIngredient] {
        (recipe.ingredientLines ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            RecipeHeroImageView(photoData: recipe.photoData, takePhoto: takePhoto)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            VStack(alignment: .leading, spacing: 10) {
                Text(recipe.name)
                    .font(.largeTitle.bold())
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text("\(recipe.cookingTimeMinutes) min")
                    Image(systemName: "person.2")
                    Text("\(recipe.serves)")
                }
                .foregroundStyle(.secondary)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section("Ingredients") {
                if ingredientLines.isEmpty {
                    Text("No ingredients yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ingredientLines) { line in
                        ingredientLineRow(for: line)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteIngredientLine(line)
                            } label: {
                                Label("Remove", systemImage: "xmark")
                            }

                            Button {
                                editedIngredientLine = line
                            } label: {
                                Label("Edit Details", systemImage: "slider.horizontal.3")
                            }
                            .tint(.blue)

                            Button {
                                substitutedIngredientLine = line
                            } label: {
                                Label("Substitute", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .tint(.purple)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)

            Section("Method") {
                Text(recipe.method.isEmpty ? "No method added." : recipe.method)
                    .foregroundStyle(recipe.method.isEmpty ? .secondary : .primary)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditRecipe = true
                } label: {
                    Text("Edit")
                }
            }
            
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    takePhoto()
                } label: {
                    Label("Take Meal Photo", systemImage: "camera")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddIngredient = true
                } label: {
                    Label("Add Ingredient", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditRecipe) {
            NavigationStack {
                RecipeFormView(recipe: recipe)
            }
        }
        .sheet(isPresented: $showingAddIngredient) {
            NavigationStack {
                AddIngredientToRecipeView(recipe: recipe)
            }
        }
        .sheet(item: $editedIngredientLine) { line in
            NavigationStack {
                EditRecipeIngredientDetailsView(line: line) {
                    deleteIngredientLine(line)
                    editedIngredientLine = nil
                }
            }
        }
        .sheet(item: $substitutedIngredientLine) { line in
            NavigationStack {
                SubstituteRecipeIngredientView(line: line)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                recipe.photoData = image.recipePhotoData
                try? modelContext.save()
            }
            .ignoresSafeArea()
        }
        .alert("Camera Unavailable", isPresented: $showingCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A camera is not available on this device.")
        }
    }

    @ViewBuilder
    private func ingredientLineRow(for line: RecipeIngredient) -> some View {
        if let ingredient = line.ingredient {
            NavigationLink {
                IngredientDetailView(ingredient: ingredient)
            } label: {
                ingredientLineContent(for: line)
            }
        } else {
            ingredientLineContent(for: line)
        }
    }

    private func ingredientLineContent(for line: RecipeIngredient) -> some View {
        HStack(spacing: 12) {
            IngredientThumbnailView(photoData: line.ingredient?.photoData)

            VStack(alignment: .leading, spacing: 2) {
                Text(line.ingredient?.name ?? "Deleted ingredient")

                if !line.trimmedPreparationMethod.isEmpty {
                    Text(line.trimmedPreparationMethod)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(line.formattedQuantity)
                .foregroundStyle(.secondary)
        }
    }

    private func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showingCameraUnavailable = true
            return
        }

        showingCamera = true
    }

    private func deleteIngredientLine(_ line: RecipeIngredient) {
        recipe.ingredientLines?.removeAll { $0.id == line.id }
        line.recipe?.ingredientLines?.removeAll { $0.id == line.id }
        modelContext.delete(line)
        try? modelContext.save()
    }
}

private extension RecipeIngredient {
    var trimmedPreparationMethod: String {
        preparationMethod.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedQuantity: String {
        let amount = quantity.formatted(.number.precision(.fractionLength(0...2)))
        guard let symbol = ingredient?.unit?.symbol, !symbol.isEmpty else {
            return amount
        }
        return "\(amount) \(symbol)"
    }
}

#Preview("Recipe Detail") {
    let previewData = PreviewData()

    NavigationStack {
        RecipeDetailView(recipe: previewData.recipe)
    }
    .modelContainer(previewData.container)
}
