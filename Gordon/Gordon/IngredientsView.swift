//
//  IngredientsView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

struct IngredientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @State private var showingAddIngredient = false
    @State private var searchText = ""

    private var filteredIngredients: [Ingredient] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return ingredients }

        return ingredients.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if ingredients.isEmpty {
                    Text("Add ingredients as you create recipes.")
                        .foregroundStyle(.secondary)
                } else if filteredIngredients.isEmpty {
                    Text("No ingredients found.")
                        .foregroundStyle(.secondary)
                }

                ForEach(filteredIngredients) { ingredient in
                    NavigationLink {
                        IngredientDetailView(ingredient: ingredient)
                    } label: {
                        HStack(spacing: 12) {
                            IngredientThumbnailView(photoData: ingredient.photoData)

                            VStack(alignment: .leading) {
                                Text(ingredient.name)
                                Text(ingredient.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteIngredients)
            }
            .listStyle(.plain)
            .navigationTitle("Ingredients")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search ingredients"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddIngredient = true
                    } label: {
                        Label("Add Ingredient", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddIngredient) {
                NavigationStack {
                    IngredientFormView()
                }
            }
        }
    }

    private func deleteIngredients(at offsets: IndexSet) {
        let deletedIngredients = offsets.map { filteredIngredients[$0] }

        for ingredient in deletedIngredients {
            for recipeLine in ingredient.recipeLines {
                modelContext.delete(recipeLine)
            }

            modelContext.delete(ingredient)
        }
    }
}

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

struct IngredientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]

    let onSave: ((Ingredient) -> Void)?

    @State private var name = ""
    @State private var defaultQuantity = 1.0
    @State private var selectedCategoryID: UUID?
    @State private var selectedUnitID: UUID?
    @State private var newCategoryName = ""
    @State private var newUnitName = ""
    @State private var newUnitSymbol = ""

    init(onSave: ((Ingredient) -> Void)? = nil) {
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Ingredient") {
                TextField("Name", text: $name)
                TextField("Default quantity", value: $defaultQuantity, format: .number)
                    .keyboardType(.decimalPad)
            }

            Section("Category") {
                Picker("Existing category", selection: $selectedCategoryID) {
                    Text("None").tag(nil as UUID?)

                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                }

                TextField("Or create a category", text: $newCategoryName)
            }

            Section("Unit") {
                Picker("Existing unit", selection: $selectedUnitID) {
                    Text("None").tag(nil as UUID?)

                    ForEach(units) { unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(unit.id as UUID?)
                    }
                }

                TextField("Or create a unit", text: $newUnitName)
                TextField("New unit symbol", text: $newUnitSymbol)
            }
        }
        .navigationTitle("New Ingredient")
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
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    defaultQuantity <= 0
                )
            }
        }
        .task {
            selectDefaultUnitIfNeeded()
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingIngredient = ingredients.first(where: {
            $0.normalizedName == trimmedName.normalizedLookupValue
        }) {
            onSave?(existingIngredient)
            dismiss()
            return
        }

        var category = categories.first { $0.id == selectedCategoryID }
        if !newCategoryName.normalizedLookupValue.isEmpty {
            category = SeedData.category(
                named: newCategoryName,
                existing: categories,
                in: modelContext
            )
        }

        var unit = units.first { $0.id == selectedUnitID }
        if !newUnitName.normalizedLookupValue.isEmpty {
            unit = SeedData.unit(
                named: newUnitName,
                symbol: newUnitSymbol,
                existing: units,
                in: modelContext
            )
        }

        let ingredient = Ingredient(
            name: trimmedName,
            defaultQuantity: defaultQuantity,
            category: category,
            unit: unit
        )
        modelContext.insert(ingredient)
        generateImage(for: ingredient)
        onSave?(ingredient)
        dismiss()
    }

    private func selectDefaultUnitIfNeeded() {
        guard selectedUnitID == nil else { return }
        selectedUnitID = units.first(where: { $0.normalizedName == "each" })?.id
    }

    private func generateImage(for ingredient: Ingredient) {
        Task { @MainActor in
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

private struct IngredientDetailImageView: View {
    let photoData: Data?

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)

                    Image(systemName: "carrot")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .containerRelativeFrame(.horizontal) { width, _ in
            width / 3
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct IngredientThumbnailView: View {
    let photoData: Data?

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)

                    Image(systemName: "carrot")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private extension Ingredient {
    var subtitle: String {
        let quantity = defaultQuantity.formatted(.number.precision(.fractionLength(0...2)))
        let unitDescription = unit?.symbol ?? "no unit"
        let categoryDescription = category?.name ?? "No category"
        return "\(quantity) \(unitDescription) | \(categoryDescription)"
    }
}

#Preview("Ingredients") {
    let previewData = PreviewData()

    IngredientsView()
        .modelContainer(previewData.container)
}

#Preview("Ingredient Detail") {
    let previewData = PreviewData()

    NavigationStack {
        IngredientDetailView(ingredient: previewData.ingredient)
    }
    .modelContainer(previewData.container)
}

#Preview("New Ingredient") {
    let previewData = PreviewData()

    NavigationStack {
        IngredientFormView()
    }
    .modelContainer(previewData.container)
}

#Preview("Ingredient Detail Image") {
    IngredientDetailImageView(photoData: nil)
        .padding()
}

#Preview("Ingredient Thumbnail") {
    IngredientThumbnailView(photoData: nil)
        .padding()
}
