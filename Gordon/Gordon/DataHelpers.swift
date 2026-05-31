//
//  DataHelpers.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

extension String {
    var normalizedLookupValue: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension Calendar {
    func startOfWeek(containing date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

enum SeedData {
    static func ensureDefaults(in modelContext: ModelContext) {
        let units = (try? modelContext.fetch(FetchDescriptor<MeasurementUnit>())) ?? []
        let categories = (try? modelContext.fetch(FetchDescriptor<IngredientCategory>())) ?? []

        let defaultUnits = [
            ("Each", "each"),
            ("Gram", "g"),
            ("Kilogram", "kg"),
            ("Millilitre", "mL"),
            ("Litre", "L"),
            ("Teaspoon", "tsp"),
            ("Tablespoon", "tbsp"),
        ]

        for (name, symbol) in defaultUnits
        where !units.contains(where: { $0.normalizedName == name.normalizedLookupValue }) {
            modelContext.insert(MeasurementUnit(name: name, symbol: symbol))
        }

        let defaultCategories = ["Produce", "Meat", "Dairy", "Pantry", "Bakery", "Frozen", "Other"]
        for name in defaultCategories
        where !categories.contains(where: { $0.normalizedName == name.normalizedLookupValue }) {
            modelContext.insert(IngredientCategory(name: name))
        }

        try? modelContext.save()
    }

    static func category(
        named name: String,
        existing categories: [IngredientCategory],
        in modelContext: ModelContext
    ) -> IngredientCategory? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        if let category = categories.first(where: {
            $0.normalizedName == trimmedName.normalizedLookupValue
        }) {
            return category
        }

        let category = IngredientCategory(name: trimmedName)
        modelContext.insert(category)
        return category
    }

    static func unit(
        named name: String,
        symbol: String,
        existing units: [MeasurementUnit],
        in modelContext: ModelContext
    ) -> MeasurementUnit? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        if let unit = units.first(where: {
            $0.normalizedName == trimmedName.normalizedLookupValue
        }) {
            return unit
        }

        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = MeasurementUnit(
            name: trimmedName,
            symbol: trimmedSymbol.isEmpty ? trimmedName : trimmedSymbol
        )
        modelContext.insert(unit)
        return unit
    }

    static func weekPlan(
        starting weekStarting: Date,
        existing plans: [WeekPlan],
        in modelContext: ModelContext
    ) -> WeekPlan {
        let calendar = Calendar.current
        if let plan = plans.first(where: {
            calendar.isDate($0.weekStarting, inSameDayAs: weekStarting)
        }) {
            return plan
        }

        let plan = WeekPlan(weekStarting: weekStarting)
        modelContext.insert(plan)
        return plan
    }
}

struct ShoppingListLine: Identifiable {
    let ingredientID: UUID
    let ingredientName: String
    let categoryName: String
    let unitSymbol: String
    var quantity: Double

    var id: String {
        "\(ingredientID.uuidString)-\(unitSymbol)"
    }

    var formattedQuantity: String {
        quantity.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func makeLines(for plan: WeekPlan?) -> [ShoppingListLine] {
        guard let plan else { return [] }

        var linesByID: [String: ShoppingListLine] = [:]

        for plannedMeal in plan.plannedMeals {
            guard let recipe = plannedMeal.recipe else { continue }

            for recipeLine in recipe.ingredientLines {
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
