//
//  IngredientDetailView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI

struct IngredientDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ingredient: Ingredient
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]
    @State private var isGeneratingImage = false

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

            Section {
                Picker("Category", selection: $ingredient.category) {
                    Text("None").tag(nil as IngredientCategory?)

                    ForEach(categories) { category in
                        Text(category.name).tag(category as IngredientCategory?)
                    }
                }
                Picker("Unit", selection: $ingredient.unit) {
                    Text("None").tag(nil as MeasurementUnit?)

                    ForEach(units) { unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(unit as MeasurementUnit?)
                    }
                }
                TextField("Default quantity", value: $ingredient.defaultQuantity, format: .number)
                    .keyboardType(.decimalPad)
            }header: {
                Text("Details")
            } footer: {
                Text("This count will be pre-filled when adding this ingredient to a recipe.")
            }
        }
        .navigationTitle(ingredient.name)
        .toolbar {
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
}

#Preview("Ingredient Detail") {
    let previewData = PreviewData()

    NavigationStack {
        IngredientDetailView(ingredient: previewData.ingredient)
    }
    .modelContainer(previewData.container)
}
