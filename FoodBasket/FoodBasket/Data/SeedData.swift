//
//  SeedData.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

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
            ("Cup", "cup"),
            ("Pinch", "pinch"),
            ("Dash", "dash"),
            ("Punnet", "punnet"),
            ("Fillet", "fillet"),
            ("Clove", "clove"),
            ("Bunch", "bunch"),
            ("Head", "head"),
            ("Stalk", "stalk"),
            ("Sprig", "sprig"),
            ("Slice", "slice"),
            ("Piece", "piece"),
            ("Packet", "packet"),
            ("Can", "can"),
            ("Jar", "jar"),
            ("Bottle", "bottle"),
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
