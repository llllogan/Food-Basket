//
//  IngredientCategorySuggestionService.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation
import FoundationModels

@MainActor
enum IngredientCategorySuggestionService {
    static var isAvailable: Bool {
        let model = SystemLanguageModel(useCase: .contentTagging)
        guard case .available = model.availability else { return false }
        return true
    }

    static func suggestedCategory(
        for ingredientName: String,
        from categories: [IngredientCategory]
    ) async -> IngredientCategory? {
        let trimmedName = ingredientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let selectableCategories = categories.filter { $0.normalizedName != "other" }
        guard !selectableCategories.isEmpty else { return nil }

        let fallbackCategory = inferredCategory(for: trimmedName, in: selectableCategories)
        let model = SystemLanguageModel(useCase: .contentTagging)
        guard case .available = model.availability else { return fallbackCategory }

        do {
            let selectableCategoryNames = selectableCategories.map(\.name)
            let request = IngredientCategorySuggestionRequest(
                ingredientName: trimmedName,
                existingCategories: selectableCategoryNames
            )
            let responseSchema = try IngredientCategorySuggestion.responseSchema(
                categoryNames: selectableCategoryNames
            )
            let session = LanguageModelSession(
                model: model,
                instructions: categorySelectionInstructions
            )
            let response = try await session.respond(
                schema: responseSchema,
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0,
                    maximumResponseTokens: 80
                )
            ) {
                categorySelectionPrompt
                request
            }

            try Task.checkCancellation()
            let suggestion = try IngredientCategorySuggestion(response.content)
            if let fallbackCategory {
                return fallbackCategory
            }

            guard suggestion.categoryName != IngredientCategorySuggestion.userShouldChooseValue else {
                return nil
            }

            return selectableCategories.first {
                $0.normalizedName == suggestion.categoryName.normalizedLookupValue
            }
        } catch {
            return fallbackCategory
        }
    }

    private static let categorySelectionInstructions = """
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

    private static let categorySelectionPrompt = """
    Categorize this ingredient request.
    If you choose an existing category, copy one category name exactly from existingCategories into categoryName.
    """

    private static func inferredCategory(
        for ingredientName: String,
        in categories: [IngredientCategory]
    ) -> IngredientCategory? {
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
        }
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
