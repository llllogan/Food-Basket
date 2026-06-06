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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @Bindable var ingredient: Ingredient
    let recipeIngredientLine: RecipeIngredient?
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]
    @State private var newCategoryName = ""
    @State private var newUnitName = ""
    @State private var newUnitSymbol = ""
    @State private var showingNewCategoryAlert = false
    @State private var showingNewUnitAlert = false
    @State private var isGeneratingImage = false
    @State private var showingCamera = false
    @State private var showingCameraUnavailable = false

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
            }

            if let recipeIngredientLine {
                RecipeIngredientDetailFields(
                    ingredient: ingredient,
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

            Section("Unit") {
                Picker("Unit", selection: $ingredient.unit) {
                    Text("None").tag(nil as MeasurementUnit?)

                    ForEach(units) { unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(unit as MeasurementUnit?)
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
            
            Section {
                TextField("Default quantity", value: $ingredient.defaultQuantity, format: .number)
                    .keyboardType(.decimalPad)
            } header: {
                Text("Default Amount")
            } footer: {
                Text("This amount will be pre-filled when adding this ingredient to a recipe. You can change this to any other amount or leave it blank to use the default.")
            }
        }
        .navigationTitle(ingredient.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
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
                        regenerateImage()
                    } label: {
                        if isGeneratingImage {
                            ProgressView()
                        } else {
                            Label("Regenerate Image", systemImage: "wand.and.sparkles")
                        }
                    }
                    .disabled(isGeneratingImage)
                }
            }
        }
        .alert("New Category", isPresented: $showingNewCategoryAlert) {
            TextField("Category name", text: $newCategoryName)

            Button("Add") {
                createCategoryFromAlert()
            }
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Cancel", role: .cancel) {}
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
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                ingredient.photoData = image.recipePhotoData
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

    private func createUnitFromAlert() {
        let normalizedName = newUnitName.normalizedLookupValue
        guard !normalizedName.isEmpty else { return }

        let unit = units.first {
            $0.normalizedName == normalizedName
        } ?? {
            let trimmedName = newUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSymbol = newUnitSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
            return MeasurementUnit(
                name: trimmedName,
                symbol: trimmedSymbol.isEmpty ? trimmedName : trimmedSymbol
            )
        }()

        if unit.modelContext == nil {
            modelContext.insert(unit)
        }

        ingredient.unit = unit
        try? modelContext.save()
    }

    private func regenerateImage() {
        isGeneratingImage = true

        Task { @MainActor in
            defer {
                isGeneratingImage = false
            }

            guard let photoData = await IngredientImageGenerator.generateImageData(
                for: ingredient.name
            ) else {
                return
            }

            ingredient.photoData = photoData
            try? modelContext.save()
        }
    }

    private func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showingCameraUnavailable = true
            return
        }

        showingCamera = true
    }
}

private struct RecipeIngredientDetailFields: View {
    let ingredient: Ingredient
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
            HStack {
                TextField("Amount", value: $line.quantity, format: .number)
                    .keyboardType(.decimalPad)

                if let symbol = ingredient.unit?.symbol, !symbol.isEmpty {
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
