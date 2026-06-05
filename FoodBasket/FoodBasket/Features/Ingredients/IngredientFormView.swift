//
//  IngredientFormView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI
import FoundationModels

struct IngredientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]

    let onSave: ((Ingredient) -> Void)?
    private let categoryModel: SystemLanguageModel

    @State private var name = ""
    @State private var defaultQuantity = 1.0
    @State private var selectedCategoryID: UUID?
    @State private var selectedUnitID: UUID?
    @State private var newCategoryName = ""
    @State private var newUnitName = ""
    @State private var newUnitSymbol = ""
    @State private var showingNewCategoryAlert = false
    @State private var showingNewUnitAlert = false
    @State private var locallyCreatedCategories: [IngredientCategory] = []
    @State private var locallyCreatedUnits: [MeasurementUnit] = []
    @State private var categorySuggestionState: CategorySuggestionState = .idle
    @State private var suggestedCategoryID: UUID?
    @State private var manuallySelectedCategoryName: String?
    @State private var didFinish = false

    init(onSave: ((Ingredient) -> Void)? = nil) {
        self.onSave = onSave
        categoryModel = SystemLanguageModel(useCase: .contentTagging)
    }

    private var categorySelection: Binding<UUID?> {
        Binding {
            selectedCategoryID
        } set: { newValue in
            guard newValue != selectedCategoryID else { return }
            selectCategory(newValue, manually: true)
        }
    }

    private var unitSelection: Binding<UUID?> {
        Binding {
            selectedUnitID
        } set: { newValue in
            selectedUnitID = newValue
            cleanupTemporaryItems(
                keepingCategoryID: selectedCategoryID,
                keepingUnitID: newValue
            )
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categorySuggestionKey: String {
        let categoryKey = categories
            .map(\.normalizedName)
            .joined(separator: "|")
        return "\(canSuggestCategory)|\(trimmedName.normalizedLookupValue)|\(categoryKey)"
    }

    private var canSuggestCategory: Bool {
        guard case .available = categoryModel.availability else { return false }
        return true
    }

    var body: some View {
        Form {
            Section("Ingredient") {
                TextField("Name", text: $name)
                Picker("Unit", selection: unitSelection) {
                    Text("None").tag(nil as UUID?)

                    ForEach(units) { unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(unit.id as UUID?)
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
                Picker(selection: categorySelection) {
                    Text("None").tag(nil as UUID?)

                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                } label: {
                    HStack(spacing: 6) {
                        if categorySuggestionState == .generating {
                            ProgressView()
                                .controlSize(.small)
                        } else if case .suggested(_) = categorySuggestionState {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                        }

                        Text("Category")
                    }
                }

                Button {
                    newCategoryName = ""
                    showingNewCategoryAlert = true
                } label: {
                    Text("New Category")
                }
            }
            
            Section {
                TextField("Default quantity", value: $defaultQuantity, format: .number)
                    .keyboardType(.decimalPad)
            } header: {
                Text("Default Amount")
            } footer: {
                Text("When adding this ingredient to a recipe, this is the amount that will be used if you don't specify anything.")
            }
        }
        .navigationTitle("New Ingredient")
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
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    defaultQuantity <= 0
                )
            }
        }
        .task {
            selectDefaultUnitIfNeeded()
        }
        .task(id: categorySuggestionKey) {
            await suggestCategoryIfNeeded()
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
        .onDisappear {
            guard !didFinish else { return }
            cleanupTemporaryItems(keepingCategoryID: nil, keepingUnitID: nil)
        }
    }

    private func save() {
        if let existingIngredient = ingredients.first(where: {
            $0.normalizedName == trimmedName.normalizedLookupValue
        }) {
            cleanupTemporaryItems(keepingCategoryID: nil, keepingUnitID: nil)
            didFinish = true
            onSave?(existingIngredient)
            dismiss()
            return
        }

        var category = categories.first { $0.id == selectedCategoryID }
        category = category ?? locallyCreatedCategories.first { $0.id == selectedCategoryID }

        var unit = units.first { $0.id == selectedUnitID }
        unit = unit ?? locallyCreatedUnits.first { $0.id == selectedUnitID }

        let ingredient = Ingredient(
            name: trimmedName,
            defaultQuantity: defaultQuantity,
            category: category,
            unit: unit
        )
        modelContext.insert(ingredient)
        cleanupTemporaryItems(keepingCategoryID: category?.id, keepingUnitID: unit?.id)
        locallyCreatedCategories = []
        locallyCreatedUnits = []
        didFinish = true
        generateImage(for: ingredient)
        onSave?(ingredient)
        dismiss()
    }

    private func cancel() {
        cleanupTemporaryItems(keepingCategoryID: nil, keepingUnitID: nil)
        didFinish = true
        dismiss()
    }

    private func selectDefaultUnitIfNeeded() {
        guard selectedUnitID == nil else { return }
        selectedUnitID = units.first(where: { $0.normalizedName == "each" })?.id
    }

    private func selectCategory(_ categoryID: UUID?, manually: Bool) {
        selectedCategoryID = categoryID

        if manually {
            manuallySelectedCategoryName = trimmedName.normalizedLookupValue
            suggestedCategoryID = nil
            categorySuggestionState = .idle
        }

        cleanupTemporaryItems(
            keepingCategoryID: categoryID,
            keepingUnitID: selectedUnitID
        )
    }

    private func createCategoryFromAlert() {
        let normalizedName = newCategoryName.normalizedLookupValue
        guard !normalizedName.isEmpty else { return }

        let existingCategory = categories.first {
            $0.normalizedName == normalizedName
        } ?? locallyCreatedCategories.first {
            $0.normalizedName == normalizedName
        }

        let category: IngredientCategory
        if let existingCategory {
            category = existingCategory
        } else {
            category = IngredientCategory(
                name: newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(category)
            locallyCreatedCategories.append(category)
        }

        selectCategory(category.id, manually: true)
        try? modelContext.save()
    }

    private func createUnitFromAlert() {
        let normalizedName = newUnitName.normalizedLookupValue
        guard !normalizedName.isEmpty else { return }

        let existingUnit = units.first {
            $0.normalizedName == normalizedName
        } ?? locallyCreatedUnits.first {
            $0.normalizedName == normalizedName
        }

        let unit: MeasurementUnit
        if let existingUnit {
            unit = existingUnit
        } else {
            let trimmedName = newUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSymbol = newUnitSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
            unit = MeasurementUnit(
                name: trimmedName,
                symbol: trimmedSymbol.isEmpty ? trimmedName : trimmedSymbol
            )
            modelContext.insert(unit)
            locallyCreatedUnits.append(unit)
        }

        selectedUnitID = unit.id
        cleanupTemporaryItems(
            keepingCategoryID: selectedCategoryID,
            keepingUnitID: unit.id
        )
        try? modelContext.save()
    }

    private func cleanupTemporaryItems(keepingCategoryID: UUID?, keepingUnitID: UUID?) {
        locallyCreatedCategories.removeAll { category in
            guard category.id != keepingCategoryID else { return false }

            if category.ingredients?.isEmpty ?? true {
                modelContext.delete(category)
            }

            if selectedCategoryID == category.id {
                selectedCategoryID = nil
            }

            return true
        }

        locallyCreatedUnits.removeAll { unit in
            guard unit.id != keepingUnitID else { return false }

            if unit.ingredients?.isEmpty ?? true {
                modelContext.delete(unit)
            }

            if selectedUnitID == unit.id {
                selectedUnitID = nil
            }

            return true
        }

        try? modelContext.save()
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

    private func suggestCategoryIfNeeded() async {
        guard canSuggestCategory else {
            categorySuggestionState = .idle
            return
        }

        let ingredientName = trimmedName
        let normalizedIngredientName = ingredientName.normalizedLookupValue
        guard !ingredientName.isEmpty, manuallySelectedCategoryName != normalizedIngredientName else {
            categorySuggestionState = .idle
            return
        }

        if selectedCategoryID == suggestedCategoryID {
            selectedCategoryID = nil
        }
        suggestedCategoryID = nil
        categorySuggestionState = .generating

        do {
            try await Task.sleep(nanoseconds: 700_000_000)
            try Task.checkCancellation()

            let selectableCategoryNames = categories
                .map(\.name)
                .filter { $0.normalizedLookupValue != "other" }
            guard !selectableCategoryNames.isEmpty else {
                categorySuggestionState = .idle
                return
            }

            let request = IngredientCategorySuggestionRequest(
                ingredientName: ingredientName,
                existingCategories: selectableCategoryNames
            )
            let responseSchema = try IngredientCategorySuggestion.responseSchema(
                categoryNames: selectableCategoryNames
            )
            let session = LanguageModelSession(
                model: categoryModel,
                instructions: """
                Categorize grocery ingredients for a recipe app.
                Choose the most specific existing category from the allowed category names.
                Do not choose Other automatically. Other means the user should choose manually.
                Common examples:
                - Produce: fruit, vegetables, herbs, fresh mushrooms.
                - Meat: beef, chicken, pork, lamb, fish, seafood.
                - Dairy: milk, cheese, yoghurt, cream, butter, eggs.
                - Pantry: rice, pasta, flour, sugar, spices, oils, sauces, canned food, dry goods.
                - Bakery: bread, rolls, wraps, pastry, cakes.
                - Frozen: frozen vegetables, frozen fruit, ice cream, frozen meals.
                If none of the allowed categories fit, say the user should choose.
                Never invent or create a category.
                """
            )
            let response = try await session.respond(
                schema: responseSchema,
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0,
                    maximumResponseTokens: 80
                )
            ) {
                """
                Categorize this ingredient request.
                If you choose an existing category, copy one category name exactly from existingCategories into categoryName.
                """
                request
            }

            try Task.checkCancellation()
            applyCategorySuggestion(
                try IngredientCategorySuggestion(response.content),
                for: ingredientName,
                fallbackCategoryName: inferredCategoryName(for: ingredientName)
            )
        } catch is CancellationError {
        } catch {
            categorySuggestionState = .idle
        }
    }

    private func applyCategorySuggestion(
        _ suggestion: IngredientCategorySuggestion,
        for ingredientName: String,
        fallbackCategoryName: String?
    ) {
        guard
            trimmedName == ingredientName,
            manuallySelectedCategoryName != ingredientName.normalizedLookupValue
        else {
            return
        }
        let suggestedCategoryName = fallbackCategoryName ?? suggestion.categoryName

        guard
            suggestedCategoryName != IngredientCategorySuggestion.userShouldChooseValue,
            let category = categories.first(where: {
                $0.normalizedName == suggestedCategoryName.normalizedLookupValue
            })
        else {
            categorySuggestionState = .idle
            return
        }

        selectedCategoryID = category.id
        suggestedCategoryID = category.id
        categorySuggestionState = .suggested(category.name)
    }

    private func inferredCategoryName(for ingredientName: String) -> String? {
        let name = ingredientName.normalizedLookupValue
        let categoryKeywords: [(category: String, keywords: [String])] = [
            (
                "Produce",
                [
                    "apple", "apricot", "asparagus", "avocado", "banana", "bean",
                    "beetroot", "berry", "broccoli", "cabbage", "capsicum", "carrot",
                    "cauliflower", "celery", "chilli", "coriander", "corn", "cucumber",
                    "eggplant", "garlic", "grape", "herb", "kale", "leek", "lettuce",
                    "lime", "mango", "mushroom", "onion", "orange", "parsley", "pear",
                    "peas", "potato", "pumpkin", "spinach", "tomato", "zucchini"
                ]
            ),
            (
                "Meat",
                [
                    "bacon", "beef", "chicken", "chorizo", "fish", "ham", "lamb",
                    "mince", "pork", "prawn", "salmon", "sausage", "seafood", "steak",
                    "turkey", "veal"
                ]
            ),
            (
                "Dairy",
                [
                    "butter", "cheese", "cream", "egg", "feta", "milk", "mozzarella",
                    "parmesan", "ricotta", "sour cream", "yoghurt", "yogurt"
                ]
            ),
            (
                "Bakery",
                [
                    "bagel", "baguette", "bread", "bun", "cake", "croissant", "muffin",
                    "pastry", "pita", "roll", "sourdough", "tortilla", "wrap"
                ]
            ),
            (
                "Frozen",
                [
                    "frozen", "ice cream"
                ]
            ),
            (
                "Pantry",
                [
                    "baking powder", "can", "canned", "cereal", "chickpea", "coconut milk",
                    "flour", "honey", "lentil", "noodle", "oil", "pasta", "pepper",
                    "rice", "salt", "sauce", "spice", "stock", "sugar", "tuna", "vinegar"
                ]
            )
        ]

        guard let inferred = categoryKeywords.first(where: { _, keywords in
            keywords.contains { name.contains($0) }
        })?.category else {
            return nil
        }

        return categories.first {
            $0.normalizedName == inferred.normalizedLookupValue
        }?.name
    }
}

@Generable
private struct IngredientCategorySuggestionRequest {
    @Guide(description: "The ingredient name the person entered.")
    var ingredientName: String

    @Guide(description: "The existing category names available in the app.")
    var existingCategories: [String]

    init(ingredientName: String, existingCategories: [String]) {
        self.ingredientName = ingredientName
        self.existingCategories = existingCategories
    }
}

private enum CategorySuggestionState: Equatable {
    case idle
    case generating
    case suggested(String)
}

private struct IngredientCategorySuggestion {
    static let userShouldChooseValue = "USER_SHOULD_CHOOSE"

    let categoryName: String

    init(_ content: GeneratedContent) throws {
        categoryName = try content.value(String.self, forProperty: "categoryName")
    }

    static func responseSchema(categoryNames: [String]) throws -> GenerationSchema {
        let categorySchema = DynamicGenerationSchema(
            name: "CategoryName",
            description: "One exact allowed category name, or \(userShouldChooseValue) when the user should pick manually. Do not choose Other.",
            anyOf: categoryNames + [userShouldChooseValue]
        )
        let rootSchema = DynamicGenerationSchema(
            name: "IngredientCategorySuggestion",
            description: "The best category for a grocery ingredient.",
            properties: [
                DynamicGenerationSchema.Property(
                    name: "categoryName",
                    description: "Copy one value exactly from the allowed category names.",
                    schema: categorySchema
                )
            ]
        )

        return try GenerationSchema(root: rootSchema, dependencies: [])
    }
}

#Preview("New Ingredient") {
    let previewData = PreviewData()

    NavigationStack {
        IngredientFormView()
    }
    .modelContainer(previewData.container)
}
