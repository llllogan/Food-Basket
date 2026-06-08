//
//  RecipeURLRecipeImporter.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation
import SwiftData

@MainActor
enum RecipeURLRecipeImporter {
    static func importRecipe(
        from url: URL,
        in modelContext: ModelContext
    ) async throws -> Recipe {
        let importedRecipe = try await RecipeURLIngredientImporter.importRecipe(from: url)
        SeedData.ensureDefaults(in: modelContext)

        let ingredients = try modelContext.fetch(FetchDescriptor<Ingredient>())
        let units = try modelContext.fetch(FetchDescriptor<MeasurementUnit>())

        var ingredientsByName: [String: Ingredient] = [:]
        for ingredient in ingredients {
            if ingredientsByName[ingredient.normalizedName] == nil {
                ingredientsByName[ingredient.normalizedName] = ingredient
            }
        }
        for ingredient in ingredients {
            cacheIngredientPluralLookupNames(for: ingredient, in: &ingredientsByName)
        }

        let recipe = Recipe(
            name: recipeName(from: importedRecipe, sourceURL: url),
            method: importedRecipe.instructions.joined(separator: "\n\n"),
            cookingTimeMinutes: importedRecipe.cookingTimeMinutes ?? 0,
            serves: serves(from: importedRecipe.recipeYield),
            externalURL: url
        )
        modelContext.insert(recipe)

        var recipeLines: [RecipeIngredient] = []
        for importedIngredient in importedRecipe.ingredients {
            let matchedUnit = unit(for: importedIngredient.unitText, in: units)
            let ingredient = ingredientForImportedIngredient(
                importedIngredient,
                ingredientsByName: &ingredientsByName,
                in: modelContext
            )

            let line = RecipeIngredient(
                quantity: importedIngredient.quantity ?? 1,
                preparationMethod: sentenceCased(importedIngredient.preparationMethod ?? ""),
                sortOrder: recipeLines.count,
                ingredient: ingredient,
                unit: matchedUnit
            )
            recipeLines.append(line)
            modelContext.insert(line)
        }

        recipe.ingredientLines = recipeLines
        try modelContext.save()
        return recipe
    }

    private static func ingredientForImportedIngredient(
        _ importedIngredient: ImportedRecipeIngredient,
        ingredientsByName: inout [String: Ingredient],
        in modelContext: ModelContext
    ) -> Ingredient {
        let ingredientLookupNames = ingredientLookupCandidates(for: importedIngredient.name)

        for lookupName in ingredientLookupNames {
            if let ingredient = ingredientsByName[lookupName] {
                return ingredient
            }
        }

        let ingredient = Ingredient(
            name: titleCased(importedIngredient.name)
        )
        modelContext.insert(ingredient)
        ingredientsByName[ingredient.normalizedName] = ingredient
        cacheIngredientPluralLookupNames(for: ingredient, in: &ingredientsByName)
        return ingredient
    }

    private static func ingredientLookupCandidates(for name: String) -> [String] {
        let normalizedName = name.normalizedLookupValue
        guard !normalizedName.isEmpty else { return [] }

        var candidates = [normalizedName]
        if normalizedName.hasSuffix("s") {
            candidates.append(String(normalizedName.dropLast()))
        }

        return candidates
    }

    private static func cacheIngredientPluralLookupNames(
        for ingredient: Ingredient,
        in ingredientsByName: inout [String: Ingredient]
    ) {
        for lookupName in ingredientLookupCandidates(for: ingredient.normalizedName).dropFirst()
        where ingredientsByName[lookupName] == nil {
            ingredientsByName[lookupName] = ingredient
        }
    }

    private static func unit(for unitText: String?, in units: [MeasurementUnit]) -> MeasurementUnit? {
        guard let unitText else { return nil }

        let candidates = unitLookupCandidates(for: unitText)
        guard !candidates.isEmpty else { return nil }

        return units.first { unit in
            candidates.contains(unit.normalizedName)
                || candidates.contains(unit.symbol.normalizedLookupValue)
        }
    }

    private static func unitLookupCandidates(for unitText: String) -> Set<String> {
        let normalized = unitText.normalizedLookupValue
        guard !normalized.isEmpty else { return [] }

        let aliases: [String: [String]] = [
            "tablespoons": ["tablespoon", "tbsp"],
            "tablespoon": ["tablespoon", "tbsp"],
            "tbsp": ["tablespoon", "tbsp"],
            "tbsps": ["tablespoon", "tbsp"],
            "tbsp.": ["tablespoon", "tbsp"],
            "teaspoons": ["teaspoon", "tsp"],
            "teaspoon": ["teaspoon", "tsp"],
            "tsp": ["teaspoon", "tsp"],
            "tsps": ["teaspoon", "tsp"],
            "tsp.": ["teaspoon", "tsp"],
            "cups": ["cup"],
            "cup": ["cup"],
            "ounces": ["ounce", "oz"],
            "ounce": ["ounce", "oz"],
            "oz": ["ounce", "oz"],
            "oz.": ["ounce", "oz"],
            "pounds": ["pound", "lb"],
            "pound": ["pound", "lb"],
            "lbs": ["pound", "lb"],
            "lb": ["pound", "lb"],
            "lbs.": ["pound", "lb"],
            "lb.": ["pound", "lb"],
            "grams": ["gram", "g"],
            "gram": ["gram", "g"],
            "g": ["gram", "g"],
            "kilograms": ["kilogram", "kg"],
            "kilogram": ["kilogram", "kg"],
            "kg": ["kilogram", "kg"],
            "milliliters": ["millilitre", "milliliter", "ml"],
            "millilitres": ["millilitre", "milliliter", "ml"],
            "milliliter": ["millilitre", "milliliter", "ml"],
            "millilitre": ["millilitre", "milliliter", "ml"],
            "ml": ["millilitre", "milliliter", "ml"],
            "liters": ["litre", "liter", "l"],
            "litres": ["litre", "liter", "l"],
            "liter": ["litre", "liter", "l"],
            "litre": ["litre", "liter", "l"],
            "l": ["litre", "liter", "l"],
            "packages": ["packet", "package"],
            "package": ["packet", "package"],
            "packets": ["packet", "package"],
            "packet": ["packet", "package"],
            "cans": ["can"],
            "can": ["can"],
            "jars": ["jar"],
            "jar": ["jar"],
            "cloves": ["clove"],
            "clove": ["clove"],
            "bunches": ["bunch"],
            "bunch": ["bunch"],
            "sprigs": ["sprig"],
            "sprig": ["sprig"],
            "slices": ["slice"],
            "slice": ["slice"],
            "pieces": ["piece"],
            "piece": ["piece"],
            "pinches": ["pinch"],
            "pinch": ["pinch"],
            "dashes": ["dash"],
            "dash": ["dash"],
            "handfuls": ["handful"],
            "handful": ["handful"],
        ]

        var candidates = Set([normalized])
        if normalized.hasSuffix("s") {
            candidates.insert(String(normalized.dropLast()))
        }

        for alias in aliases[normalized] ?? [] {
            candidates.insert(alias.normalizedLookupValue)
        }

        return candidates
    }

    private static func recipeName(from importedRecipe: ImportedRecipeIngredients, sourceURL: URL) -> String {
        if let title = importedRecipe.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }

        let fallbackName = sourceURL
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !fallbackName.isEmpty {
            return titleCased(fallbackName)
        }

        return sourceURL.host ?? "Imported Recipe"
    }

    private static func serves(from recipeYield: String?) -> Int {
        guard let recipeYield else { return 0 }

        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: recipeYield,
                range: NSRange(recipeYield.startIndex..<recipeYield.endIndex, in: recipeYield)
              ),
              let range = Range(match.range, in: recipeYield),
              let serves = Int(recipeYield[range]) else {
            return 0
        }

        return serves
    }

    private static func titleCased(_ value: String) -> String {
        value
            .normalizedLookupValue
            .split(separator: " ")
            .map { word in
                word
                    .split(separator: "-")
                    .map { part in
                        guard let first = part.first else { return "" }
                        return first.uppercased() + part.dropFirst()
                    }
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }

    private static func sentenceCased(_ value: String) -> String {
        let lowercased = value.normalizedLookupValue
        guard let first = lowercased.first else { return "" }
        return first.uppercased() + lowercased.dropFirst()
    }
}
