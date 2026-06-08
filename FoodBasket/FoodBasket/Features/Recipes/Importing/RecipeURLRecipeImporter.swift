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
        var units = try modelContext.fetch(FetchDescriptor<MeasurementUnit>())

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
            let matchedUnit = unit(
                for: importedIngredient.unitText,
                in: &units,
                modelContext: modelContext
            )
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

    private static func unit(
        for unitText: String?,
        in units: inout [MeasurementUnit],
        modelContext: ModelContext
    ) -> MeasurementUnit? {
        let importedUnitText = normalizedImportedUnitText(unitText)
        guard !importedUnitText.isEmpty else { return nil }

        let candidates = unitLookupCandidates(for: importedUnitText)
        guard !candidates.isEmpty else { return nil }

        if let existingUnit = units.first(where: { unit in
            candidates.contains(unit.normalizedName)
                || candidates.contains(unit.symbol.normalizedLookupValue)
        }) {
            return existingUnit
        }

        let template = unitCreationTemplate(for: importedUnitText)
        let unit = MeasurementUnit(name: template.name, symbol: template.symbol)
        modelContext.insert(unit)
        units.append(unit)
        return unit
    }

    private static func unitLookupCandidates(for unitText: String) -> Set<String> {
        let normalized = unitText.normalizedLookupValue
        guard !normalized.isEmpty else { return [] }

        let aliases: [String: [String]] = [
            "each": ["each", "ea"],
            "ea": ["each", "ea"],
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
            "fluid ounces": ["fluid ounce", "fl oz"],
            "fluid ounce": ["fluid ounce", "fl oz"],
            "fl ounces": ["fluid ounce", "fl oz"],
            "fl ounce": ["fluid ounce", "fl oz"],
            "fl oz": ["fluid ounce", "fl oz"],
            "fl oz.": ["fluid ounce", "fl oz"],
            "fl. oz": ["fluid ounce", "fl oz"],
            "fl. oz.": ["fluid ounce", "fl oz"],
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
            "sticks": ["stick"],
            "stick": ["stick"],
            "pinches": ["pinch"],
            "pinch": ["pinch"],
            "dashes": ["dash"],
            "dash": ["dash"],
            "punnets": ["punnet"],
            "punnet": ["punnet"],
            "fillets": ["fillet"],
            "fillet": ["fillet"],
            "heads": ["head"],
            "head": ["head"],
            "stalks": ["stalk"],
            "stalk": ["stalk"],
            "bottles": ["bottle"],
            "bottle": ["bottle"],
            "bags": ["bag"],
            "bag": ["bag"],
            "boxes": ["box"],
            "box": ["box"],
            "tins": ["can", "tin"],
            "tin": ["can", "tin"],
            "containers": ["container"],
            "container": ["container"],
            "cartons": ["carton"],
            "carton": ["carton"],
            "sheets": ["sheet"],
            "sheet": ["sheet"],
            "wedges": ["wedge"],
            "wedge": ["wedge"],
            "blocks": ["block"],
            "block": ["block"],
            "drops": ["drop"],
            "drop": ["drop"],
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

    private static func normalizedImportedUnitText(_ unitText: String?) -> String {
        guard let unitText else { return "" }

        return unitText
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static func unitCreationTemplate(for unitText: String) -> UnitCreationTemplate {
        for candidate in unitLookupCandidates(for: unitText) {
            if let template = unitCreationTemplates[candidate] {
                return template
            }
        }

        return UnitCreationTemplate(name: titleCased(unitText), symbol: unitText)
    }

    private static let unitCreationTemplates: [String: UnitCreationTemplate] = [
        "each": UnitCreationTemplate(name: "Each", symbol: "each"),
        "ea": UnitCreationTemplate(name: "Each", symbol: "each"),
        "tablespoon": UnitCreationTemplate(name: "Tablespoon", symbol: "tbsp"),
        "tbsp": UnitCreationTemplate(name: "Tablespoon", symbol: "tbsp"),
        "teaspoon": UnitCreationTemplate(name: "Teaspoon", symbol: "tsp"),
        "tsp": UnitCreationTemplate(name: "Teaspoon", symbol: "tsp"),
        "cup": UnitCreationTemplate(name: "Cup", symbol: "cup"),
        "fluid ounce": UnitCreationTemplate(name: "Fluid Ounce", symbol: "fl oz"),
        "fl oz": UnitCreationTemplate(name: "Fluid Ounce", symbol: "fl oz"),
        "ounce": UnitCreationTemplate(name: "Ounce", symbol: "oz"),
        "oz": UnitCreationTemplate(name: "Ounce", symbol: "oz"),
        "pound": UnitCreationTemplate(name: "Pound", symbol: "lb"),
        "lb": UnitCreationTemplate(name: "Pound", symbol: "lb"),
        "gram": UnitCreationTemplate(name: "Gram", symbol: "g"),
        "g": UnitCreationTemplate(name: "Gram", symbol: "g"),
        "kilogram": UnitCreationTemplate(name: "Kilogram", symbol: "kg"),
        "kg": UnitCreationTemplate(name: "Kilogram", symbol: "kg"),
        "millilitre": UnitCreationTemplate(name: "Millilitre", symbol: "mL"),
        "milliliter": UnitCreationTemplate(name: "Millilitre", symbol: "mL"),
        "ml": UnitCreationTemplate(name: "Millilitre", symbol: "mL"),
        "litre": UnitCreationTemplate(name: "Litre", symbol: "L"),
        "liter": UnitCreationTemplate(name: "Litre", symbol: "L"),
        "l": UnitCreationTemplate(name: "Litre", symbol: "L"),
        "packet": UnitCreationTemplate(name: "Packet", symbol: "packet"),
        "package": UnitCreationTemplate(name: "Packet", symbol: "packet"),
        "can": UnitCreationTemplate(name: "Can", symbol: "can"),
        "tin": UnitCreationTemplate(name: "Can", symbol: "can"),
        "jar": UnitCreationTemplate(name: "Jar", symbol: "jar"),
        "clove": UnitCreationTemplate(name: "Clove", symbol: "clove"),
        "bunch": UnitCreationTemplate(name: "Bunch", symbol: "bunch"),
        "sprig": UnitCreationTemplate(name: "Sprig", symbol: "sprig"),
        "slice": UnitCreationTemplate(name: "Slice", symbol: "slice"),
        "piece": UnitCreationTemplate(name: "Piece", symbol: "piece"),
        "stick": UnitCreationTemplate(name: "Stick", symbol: "stick"),
        "pinch": UnitCreationTemplate(name: "Pinch", symbol: "pinch"),
        "dash": UnitCreationTemplate(name: "Dash", symbol: "dash"),
        "punnet": UnitCreationTemplate(name: "Punnet", symbol: "punnet"),
        "fillet": UnitCreationTemplate(name: "Fillet", symbol: "fillet"),
        "head": UnitCreationTemplate(name: "Head", symbol: "head"),
        "stalk": UnitCreationTemplate(name: "Stalk", symbol: "stalk"),
        "bottle": UnitCreationTemplate(name: "Bottle", symbol: "bottle"),
        "bag": UnitCreationTemplate(name: "Bag", symbol: "bag"),
        "box": UnitCreationTemplate(name: "Box", symbol: "box"),
        "container": UnitCreationTemplate(name: "Container", symbol: "container"),
        "carton": UnitCreationTemplate(name: "Carton", symbol: "carton"),
        "sheet": UnitCreationTemplate(name: "Sheet", symbol: "sheet"),
        "wedge": UnitCreationTemplate(name: "Wedge", symbol: "wedge"),
        "block": UnitCreationTemplate(name: "Block", symbol: "block"),
        "drop": UnitCreationTemplate(name: "Drop", symbol: "drop"),
        "handful": UnitCreationTemplate(name: "Handful", symbol: "handful"),
    ]

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

private struct UnitCreationTemplate {
    let name: String
    let symbol: String
}
