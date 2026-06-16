//
//  IngredientDetailView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI
import ImagePlayground
import UIKit

struct IngredientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @Bindable var ingredient: Ingredient
    let recipeIngredientLine: RecipeIngredient?
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @State private var newCategoryName = ""
    @State private var showingNewCategoryAlert = false
    @State private var showingImagePlayground = false
    @State private var showingCamera = false
    @State private var showingCameraUnavailable = false
    @State private var showingDeleteConfirmation = false

    private var usedRecipes: [Recipe] {
        Self.usedRecipes(for: ingredient)
    }

    private var usedRecipesText: String {
        let count = usedRecipes.count
        return "Used in \(count) \(count == 1 ? "recipe" : "recipes")"
    }

    private var trimmedName: String {
        ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canGenerateIngredientImage: Bool {
        supportsImagePlayground && !trimmedName.isEmpty
    }

    private var imagePlaygroundPrompt: String {
        IngredientImagePlayground.prompt(for: trimmedName)
    }

    init(
        ingredient: Ingredient,
        recipeIngredientLine: RecipeIngredient? = nil
    ) {
        self.ingredient = ingredient
        self.recipeIngredientLine = recipeIngredientLine
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    IngredientDetailImageView(photoData: ingredient.photoData)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Name", text: $ingredient.name)
                    .onChange(of: ingredient.name) {
                        ingredient.normalizedName = ingredient.name.normalizedLookupValue
                    }

                NavigationLink {
                    IngredientRecipesView(ingredient: ingredient)
                } label: {
                    Text(usedRecipesText)
                        .foregroundStyle(.secondary)
                }
            }

            if let recipeIngredientLine {
                RecipeIngredientDetailFields(
                    line: recipeIngredientLine,
                    recipeName: recipeIngredientLine.recipe?.name
                )
            }

            Section("Category") {
                Picker("Category", selection: $ingredient.category) {
                    Text("None").tag(nil as IngredientCategory?)

                    ForEach(categories) { category in
                        Text(category.name).tag(category as IngredientCategory?)
                    }
                }

                Button {
                    newCategoryName = ""
                    showingNewCategoryAlert = true
                } label: {
                    Text("New Category")
                }
            }
        }
        .navigationTitle(ingredient.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Ingredient", systemImage: "trash")
                }
                .tint(.red)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    takePhoto()
                } label: {
                    Label("Take Ingredient Photo", systemImage: "camera")
                }
            }

            if supportsImagePlayground {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImagePlayground()
                    } label: {
                        Label("Generate Image", image: "custom.photo.badge.sparkles")
                    }
                    .disabled(!canGenerateIngredientImage)
                }
            }
        }
        .alert("Delete Ingredient?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteIngredient()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(ingredient.name) and remove it from any recipes that use it.")
        }
        .alert("New Category", isPresented: $showingNewCategoryAlert) {
            TextField("Category name", text: $newCategoryName)

            Button("Add") {
                createCategoryFromAlert()
            }
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                ingredient.photoData = image.recipePhotoData
                try? modelContext.save()
            }
            .ignoresSafeArea()
        }
        .imagePlaygroundSheet(
            isPresented: $showingImagePlayground,
            concept: imagePlaygroundPrompt
        ) { imageURL in
            applyGeneratedImage(at: imageURL)
        }
        .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])
        .alert("Camera Unavailable", isPresented: $showingCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A camera is not available on this device.")
        }
    }

    private func createCategoryFromAlert() {
        let normalizedName = newCategoryName.normalizedLookupValue
        guard !normalizedName.isEmpty else { return }

        let category = categories.first {
            $0.normalizedName == normalizedName
        } ?? IngredientCategory(
            name: newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if category.modelContext == nil {
            modelContext.insert(category)
        }

        ingredient.category = category
        try? modelContext.save()
    }

    private func showImagePlayground() {
        guard canGenerateIngredientImage else { return }
        showingImagePlayground = true
    }

    private func applyGeneratedImage(at imageURL: URL) {
        guard let photoData = IngredientImagePlayground.photoData(from: imageURL) else { return }
        ingredient.photoData = photoData
        try? modelContext.save()
    }

    private func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showingCameraUnavailable = true
            return
        }

        showingCamera = true
    }

    private func deleteIngredient() {
        for recipeLine in ingredient.recipeLines ?? [] {
            modelContext.delete(recipeLine)
        }

        modelContext.delete(ingredient)
        try? modelContext.save()
        dismiss()
    }

    fileprivate static func usedRecipes(for ingredient: Ingredient) -> [Recipe] {
        var recipesByID: [UUID: Recipe] = [:]

        for recipeLine in ingredient.recipeLines ?? [] {
            guard let recipe = recipeLine.recipe else { continue }
            recipesByID[recipe.id] = recipe
        }

        return recipesByID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

private struct IngredientRecipesView: View {
    let ingredient: Ingredient

    private var recipes: [Recipe] {
        IngredientDetailView.usedRecipes(for: ingredient)
    }

    var body: some View {
        List {
            if recipes.isEmpty {
                ContentUnavailableView {
                    Label("No Recipes", systemImage: "book.closed")
                } description: {
                    Text("This ingredient is not used in any recipes yet.")
                }
                .listRowSeparator(.hidden)
            }

            ForEach(recipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    HStack(spacing: 12) {
                        RecipeThumbnailView(photoData: recipe.photoData)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)

                            Text(recipeListSubtitle(for: recipe))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(ingredient.name)
        .toolbarTitleDisplayMode(.inline)
    }

    private func recipeListSubtitle(for recipe: Recipe) -> String {
        let ingredientDescription = "\(recipe.ingredientLines?.count ?? 0) ingredients"
        guard let mealTypeName = recipe.mealType?.name, !mealTypeName.isEmpty else {
            return ingredientDescription
        }

        return "\(mealTypeName) | \(ingredientDescription)"
    }
}

private struct RecipeIngredientDetailFields: View {
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]
    @Bindable var line: RecipeIngredient
    let recipeName: String?

    private var sectionTitle: String {
        let trimmedRecipeName = recipeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedRecipeName.isEmpty else {
            return "Recipe Details"
        }

        return "Details for \(trimmedRecipeName)"
    }

    var body: some View {
        Section {
            
            TextField("Preparation instructions", text: $line.preparationMethod, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(2...4)
            
            Picker("Unit", selection: $line.unit) {
                Text("None").tag(nil as MeasurementUnit?)

                ForEach(units) { unit in
                    Text("\(unit.name) (\(unit.symbol))").tag(unit as MeasurementUnit?)
                }
            }
            
            HStack {
                TextField("Amount", value: $line.quantity, format: .number)
                    .keyboardType(.decimalPad)

                if let symbol = line.unit?.symbol, !symbol.isEmpty {
                    Text(symbol)
                        .foregroundStyle(.secondary)
                }
            }

            
            
        } header: {
            Text(sectionTitle)
        }
    }
}

#Preview("Ingredient Detail") {
    let previewData = PreviewData()

    NavigationStack {
        IngredientDetailView(ingredient: previewData.ingredient)
    }
    .modelContainer(previewData.container)
}
