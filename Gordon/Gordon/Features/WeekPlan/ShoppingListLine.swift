//
//  ShoppingListLine.swift
//  Gordon
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

    static func makeLines(for plan: WeekPlan?) -> [ShoppingListLine] {
        guard let plan else { return [] }

        var linesByID: [String: ShoppingListLine] = [:]

        for plannedMeal in plan.plannedMeals ?? [] {
            guard let recipe = plannedMeal.recipe else { continue }

            for recipeLine in recipe.ingredientLines ?? [] {
                guard let ingredient = recipeLine.ingredient else { continue }

                let unitSymbol = ingredient.unit?.symbol ?? ""
                let key = "\(ingredient.id.uuidString)-\(unitSymbol)"
                let quantity = recipeLine.quantity * plannedMeal.quantityMultiplier

                if linesByID[key] != nil {
                    linesByID[key]?.quantity += quantity
                } else {
                    linesByID[key] = ShoppingListLine(
                        ingredientID: ingredient.id,
                        ingredientName: ingredient.name,
                        categoryName: ingredient.category?.name ?? "Other",
                        unitSymbol: unitSymbol,
                        photoData: ingredient.photoData,
                        quantity: quantity
                    )
                }
            }
        }

        return linesByID.values.sorted {
            if $0.categoryName == $1.categoryName {
                return $0.ingredientName.localizedCaseInsensitiveCompare($1.ingredientName) == .orderedAscending
            }
            return $0.categoryName.localizedCaseInsensitiveCompare($1.categoryName) == .orderedAscending
        }
    }
}
