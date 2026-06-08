//
//  ShoppingListLine.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import Foundation

struct ShoppingListLine: Identifiable {
    let ingredientID: UUID
    let ingredientName: String
    let categoryName: String
    var unitSymbol: String
    let photoData: Data?
    var quantity: Double
    var recipeUsages: [ShoppingListRecipeUsage] = []

    var id: String {
        "\(ingredientID.uuidString)-\(unitSymbol)"
    }

    var formattedQuantity: String {
        quantity.formatted(.number.precision(.fractionLength(0...2)))
    }

    var formattedAmount: String {
        guard !unitSymbol.isEmpty else { return formattedQuantity }
        return "\(formattedQuantity) \(unitSymbol)"
    }

    var recipeUsageSummary: String {
        let sortedUsages = recipeUsages
            .sorted {
                if $0.firstSortOrder == $1.firstSortOrder {
                    return $0.recipeName.localizedCaseInsensitiveCompare($1.recipeName) == .orderedAscending
                }

                return $0.firstSortOrder < $1.firstSortOrder
            }

        guard sortedUsages.count != 1 else {
            return sortedUsages[0].recipeName
        }

        return sortedUsages
            .map(\.formattedUsage)
            .joined(separator: " | ")
    }

    static func makeLines(for plan: WeekPlan?) -> [ShoppingListLine] {
        guard let plan else { return [] }

        var linesByID: [String: ShoppingListLine] = [:]

        for plannedMeal in (plan.plannedMeals ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let recipe = plannedMeal.recipe else { continue }
            addLines(
                from: recipe,
                multiplier: plannedMeal.quantityMultiplier,
                firstSortOrder: plannedMeal.sortOrder,
                to: &linesByID
            )
        }

        return sortedLines(from: linesByID)
    }

    static func makeLines(for recipe: Recipe) -> [ShoppingListLine] {
        var linesByID: [String: ShoppingListLine] = [:]
        addLines(from: recipe, multiplier: 1, to: &linesByID)
        return sortedLines(from: linesByID)
    }

    private static func addLines(
        from recipe: Recipe,
        multiplier: Double,
        firstSortOrder: Int = 0,
        to linesByID: inout [String: ShoppingListLine]
    ) {
        for recipeLine in recipe.ingredientLines ?? [] {
            guard let ingredient = recipeLine.ingredient else { continue }

            let amount = ShoppingListUnitConversion.normalizedAmount(
                quantity: recipeLine.quantity * multiplier,
                unit: recipeLine.unit
            )
            let key = "\(ingredient.id.uuidString)-\(amount.aggregationUnitSymbol)"
            let quantity = amount.quantity

            if linesByID[key] != nil {
                linesByID[key]?.quantity += quantity
                linesByID[key]?.addRecipeUsage(
                    recipeID: recipe.id,
                    recipeName: recipe.name,
                    quantity: quantity,
                    firstSortOrder: firstSortOrder
                )
            } else {
                linesByID[key] = ShoppingListLine(
                    ingredientID: ingredient.id,
                    ingredientName: ingredient.name,
                    categoryName: ingredient.category?.name ?? "Other",
                    unitSymbol: amount.unitSymbol,
                    photoData: ingredient.photoData,
                    quantity: quantity,
                    recipeUsages: [
                        ShoppingListRecipeUsage(
                            recipeID: recipe.id,
                            recipeName: recipe.name,
                            quantity: quantity,
                            unitSymbol: amount.unitSymbol,
                            firstSortOrder: firstSortOrder
                        ),
                    ]
                )
            }
        }
    }

    private static func sortedLines(from linesByID: [String: ShoppingListLine]) -> [ShoppingListLine] {
        return linesByID.values.map(ShoppingListUnitConversion.linePreparedForDisplay).sorted {
            if $0.categoryName == $1.categoryName {
                return $0.ingredientName.localizedCaseInsensitiveCompare($1.ingredientName) == .orderedAscending
            }
            return $0.categoryName.localizedCaseInsensitiveCompare($1.categoryName) == .orderedAscending
        }
    }

    private mutating func addRecipeUsage(
        recipeID: UUID,
        recipeName: String,
        quantity: Double,
        firstSortOrder: Int
    ) {
        guard let existingIndex = recipeUsages.firstIndex(where: { $0.recipeID == recipeID }) else {
            recipeUsages.append(
                ShoppingListRecipeUsage(
                    recipeID: recipeID,
                    recipeName: recipeName,
                    quantity: quantity,
                    unitSymbol: unitSymbol,
                    firstSortOrder: firstSortOrder
                )
            )
            return
        }

        recipeUsages[existingIndex].quantity += quantity
        recipeUsages[existingIndex].firstSortOrder = min(
            recipeUsages[existingIndex].firstSortOrder,
            firstSortOrder
        )
    }
}

struct ShoppingListRecipeUsage {
    let recipeID: UUID
    let recipeName: String
    var quantity: Double
    var unitSymbol: String
    var firstSortOrder: Int

    private var formattedQuantity: String {
        quantity.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var formattedAmount: String {
        guard !unitSymbol.isEmpty else { return formattedQuantity }
        return "\(formattedQuantity) \(unitSymbol)"
    }

    var formattedUsage: String {
        "\(recipeName) - \(formattedAmount)"
    }
}

private enum ShoppingListUnitConversion {
    struct NormalizedAmount {
        let quantity: Double
        let unitSymbol: String
        let aggregationUnitSymbol: String
    }

    private enum UnitFamily {
        case mass
        case volume

        var baseSymbol: String {
            switch self {
            case .mass:
                return "g"
            case .volume:
                return "mL"
            }
        }
    }

    private struct UnitDefinition {
        let family: UnitFamily
        let baseUnitsPerUnit: Double
    }

    private struct DisplayUnit {
        let symbol: String
        let baseUnitsPerUnit: Double
    }

    static func normalizedAmount(
        quantity: Double,
        unit: MeasurementUnit?
    ) -> NormalizedAmount {
        guard let definition = definition(for: unit) else {
            let unitSymbol = unit?.symbol.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return NormalizedAmount(
                quantity: quantity,
                unitSymbol: unitSymbol,
                aggregationUnitSymbol: unitSymbol
            )
        }

        return NormalizedAmount(
            quantity: quantity * definition.baseUnitsPerUnit,
            unitSymbol: definition.family.baseSymbol,
            aggregationUnitSymbol: definition.family.baseSymbol
        )
    }

    static func linePreparedForDisplay(_ line: ShoppingListLine) -> ShoppingListLine {
        guard let displayUnit = preferredDisplayUnit(
            forBaseQuantity: line.quantity,
            baseSymbol: line.unitSymbol
        ) else {
            return line
        }

        var displayLine = line
        displayLine.quantity = line.quantity / displayUnit.baseUnitsPerUnit
        displayLine.unitSymbol = displayUnit.symbol
        displayLine.recipeUsages = line.recipeUsages.map { usage in
            var displayUsage = usage
            displayUsage.quantity = usage.quantity / displayUnit.baseUnitsPerUnit
            displayUsage.unitSymbol = displayUnit.symbol
            return displayUsage
        }
        return displayLine
    }

    private static func definition(for unit: MeasurementUnit?) -> UnitDefinition? {
        unitLookupCandidates(for: unit)
            .lazy
            .compactMap { unitDefinitions[$0] }
            .first
    }

    private static func preferredDisplayUnit(
        forBaseQuantity quantity: Double,
        baseSymbol: String
    ) -> DisplayUnit? {
        let absoluteQuantity = abs(quantity)

        switch baseSymbol {
        case "g":
            if absoluteQuantity > 0, absoluteQuantity < 1 {
                return DisplayUnit(symbol: "mg", baseUnitsPerUnit: 0.001)
            }

            if absoluteQuantity >= 1_000 {
                return DisplayUnit(symbol: "kg", baseUnitsPerUnit: 1_000)
            }

            return DisplayUnit(symbol: "g", baseUnitsPerUnit: 1)
        case "mL":
            if absoluteQuantity >= 1_000 {
                return DisplayUnit(symbol: "L", baseUnitsPerUnit: 1_000)
            }

            return DisplayUnit(symbol: "mL", baseUnitsPerUnit: 1)
        default:
            return nil
        }
    }

    private static func unitLookupCandidates(for unit: MeasurementUnit?) -> [String] {
        guard let unit else { return [] }

        var seen: Set<String> = []
        var candidates: [String] = []

        for value in [unit.name, unit.normalizedName, unit.symbol] {
            for candidate in normalizedUnitCandidates(from: value) where !seen.contains(candidate) {
                seen.insert(candidate)
                candidates.append(candidate)
            }
        }

        return candidates
    }

    private static func normalizedUnitCandidates(from text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return [] }

        var candidates = [normalized]
        if normalized.hasSuffix("s") {
            candidates.append(String(normalized.dropLast()))
        }

        return candidates
    }

    private static let unitDefinitions: [String: UnitDefinition] = [
        "milligram": UnitDefinition(family: .mass, baseUnitsPerUnit: 0.001),
        "mg": UnitDefinition(family: .mass, baseUnitsPerUnit: 0.001),
        "gram": UnitDefinition(family: .mass, baseUnitsPerUnit: 1),
        "g": UnitDefinition(family: .mass, baseUnitsPerUnit: 1),
        "kilogram": UnitDefinition(family: .mass, baseUnitsPerUnit: 1_000),
        "kg": UnitDefinition(family: .mass, baseUnitsPerUnit: 1_000),
        "ounce": UnitDefinition(family: .mass, baseUnitsPerUnit: 28.349523125),
        "oz": UnitDefinition(family: .mass, baseUnitsPerUnit: 28.349523125),
        "pound": UnitDefinition(family: .mass, baseUnitsPerUnit: 453.59237),
        "lb": UnitDefinition(family: .mass, baseUnitsPerUnit: 453.59237),
        "millilitre": UnitDefinition(family: .volume, baseUnitsPerUnit: 1),
        "milliliter": UnitDefinition(family: .volume, baseUnitsPerUnit: 1),
        "ml": UnitDefinition(family: .volume, baseUnitsPerUnit: 1),
        "litre": UnitDefinition(family: .volume, baseUnitsPerUnit: 1_000),
        "liter": UnitDefinition(family: .volume, baseUnitsPerUnit: 1_000),
        "l": UnitDefinition(family: .volume, baseUnitsPerUnit: 1_000),
        "teaspoon": UnitDefinition(family: .volume, baseUnitsPerUnit: 5),
        "tsp": UnitDefinition(family: .volume, baseUnitsPerUnit: 5),
        "tablespoon": UnitDefinition(family: .volume, baseUnitsPerUnit: 20),
        "tbsp": UnitDefinition(family: .volume, baseUnitsPerUnit: 20),
        "tbs": UnitDefinition(family: .volume, baseUnitsPerUnit: 20),
        "dessertspoon": UnitDefinition(family: .volume, baseUnitsPerUnit: 10),
        "dsp": UnitDefinition(family: .volume, baseUnitsPerUnit: 10),
        "cup": UnitDefinition(family: .volume, baseUnitsPerUnit: 250),
        "fluid ounce": UnitDefinition(family: .volume, baseUnitsPerUnit: 29.5735295625),
        "fl oz": UnitDefinition(family: .volume, baseUnitsPerUnit: 29.5735295625),
    ]
}
