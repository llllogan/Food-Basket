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
    let unitSymbol: String
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

            let unitSymbol = ingredient.unit?.symbol ?? ""
            let key = "\(ingredient.id.uuidString)-\(unitSymbol)"
            let quantity = recipeLine.quantity * multiplier

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
                    unitSymbol: unitSymbol,
                    photoData: ingredient.photoData,
                    quantity: quantity,
                    recipeUsages: [
                        ShoppingListRecipeUsage(
                            recipeID: recipe.id,
                            recipeName: recipe.name,
                            quantity: quantity,
                            unitSymbol: unitSymbol,
                            firstSortOrder: firstSortOrder
                        ),
                    ]
                )
            }
        }
    }

    private static func sortedLines(from linesByID: [String: ShoppingListLine]) -> [ShoppingListLine] {
        return linesByID.values.sorted {
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
    let unitSymbol: String
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
