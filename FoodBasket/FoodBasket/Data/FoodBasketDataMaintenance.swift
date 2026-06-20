//
//  FoodBasketDataMaintenance.swift
//  Food Basket
//
//  Created by Codex on 11/6/2026.
//

import Foundation
import SwiftData

@MainActor
enum FoodBasketDataMaintenance {
    @discardableResult
    static func deduplicateMealTypes(in modelContext: ModelContext) throws -> Int {
        let mealTypes = try modelContext.fetch(FetchDescriptor<MealType>())
        guard mealTypes.count > 1 else { return 0 }

        var changed = normalizeMealTypeLookupValues(mealTypes)
        let recipes = try modelContext.fetch(FetchDescriptor<Recipe>())
        let portions = try modelContext.fetch(FetchDescriptor<PlannedMealPortion>())
        let usageCounts = mealTypeUsageCounts(recipes: recipes, portions: portions)

        var replacementsByObjectID: [ObjectIdentifier: MealType] = [:]
        var replacementIDsByRemovedID: [UUID: UUID] = [:]
        var duplicatesToRemove: [MealType] = []

        for duplicateGroup in duplicateGroups(in: mealTypes) {
            let survivor = survivor(in: duplicateGroup, usageCounts: usageCounts)
            for duplicate in duplicateGroup where duplicate !== survivor {
                replacementsByObjectID[ObjectIdentifier(duplicate)] = survivor
                replacementIDsByRemovedID[duplicate.id] = survivor.id
                duplicatesToRemove.append(duplicate)
            }
        }

        guard !duplicatesToRemove.isEmpty else {
            if changed {
                try modelContext.save()
            }
            return 0
        }

        changed = reassignRecipes(
            recipes,
            replacementsByObjectID: replacementsByObjectID
        ) || changed
        changed = reassignPlannedMealPortions(
            portions,
            replacementsByObjectID: replacementsByObjectID
        ) || changed
        changed = repairExcludedCalendarMealTypeIDs(
            replacementIDsByRemovedID: replacementIDsByRemovedID
        ) || changed

        for duplicate in duplicatesToRemove {
            modelContext.delete(duplicate)
        }

        try modelContext.save()
        return duplicatesToRemove.count
    }

    @discardableResult
    static func deduplicateMeasurementUnits(in modelContext: ModelContext) throws -> Int {
        let units = try modelContext.fetch(FetchDescriptor<MeasurementUnit>())
        guard units.count > 1 else { return 0 }

        var changed = normalizeMeasurementUnitLookupValues(units)
        let recipeIngredients = try modelContext.fetch(FetchDescriptor<RecipeIngredient>())
        let usageCounts = measurementUnitUsageCounts(recipeIngredients: recipeIngredients)

        var replacementsByObjectID: [ObjectIdentifier: MeasurementUnit] = [:]
        var duplicatesToRemove: [MeasurementUnit] = []

        for duplicateGroup in duplicateGroups(in: units) {
            let survivor = survivor(in: duplicateGroup, usageCounts: usageCounts)
            for duplicate in duplicateGroup where duplicate !== survivor {
                replacementsByObjectID[ObjectIdentifier(duplicate)] = survivor
                duplicatesToRemove.append(duplicate)
            }
        }

        guard !duplicatesToRemove.isEmpty else {
            if changed {
                try modelContext.save()
            }
            return 0
        }

        changed = reassignRecipeIngredientUnits(
            recipeIngredients,
            replacementsByObjectID: replacementsByObjectID
        ) || changed

        for duplicate in duplicatesToRemove {
            modelContext.delete(duplicate)
        }

        try modelContext.save()
        return duplicatesToRemove.count
    }

    private static func normalizeMealTypeLookupValues(_ mealTypes: [MealType]) -> Bool {
        var changed = false

        for mealType in mealTypes {
            let normalizedName = mealType.name.normalizedLookupValue
            guard mealType.normalizedName != normalizedName else { continue }
            mealType.normalizedName = normalizedName
            changed = true
        }

        return changed
    }

    private static func normalizeMeasurementUnitLookupValues(_ units: [MeasurementUnit]) -> Bool {
        var changed = false

        for unit in units {
            let normalizedName = unit.name.normalizedLookupValue
            guard unit.normalizedName != normalizedName else { continue }
            unit.normalizedName = normalizedName
            changed = true
        }

        return changed
    }

    private static func duplicateGroups(in mealTypes: [MealType]) -> [[MealType]] {
        Dictionary(grouping: mealTypes) { mealType in
            mealType.normalizedName.isEmpty
                ? mealType.name.normalizedLookupValue
                : mealType.normalizedName
        }
        .values
        .filter { group in
            group.count > 1 && !(group.first?.normalizedName.isEmpty ?? true)
        }
    }

    private static func duplicateGroups(in units: [MeasurementUnit]) -> [[MeasurementUnit]] {
        Dictionary(grouping: units) { unit in
            unit.normalizedName.isEmpty
                ? unit.name.normalizedLookupValue
                : unit.normalizedName
        }
        .values
        .filter { group in
            group.count > 1 && !(group.first?.normalizedName.isEmpty ?? true)
        }
    }

    private static func mealTypeUsageCounts(
        recipes: [Recipe],
        portions: [PlannedMealPortion]
    ) -> [ObjectIdentifier: Int] {
        var usageCounts: [ObjectIdentifier: Int] = [:]

        for recipe in recipes {
            guard let mealType = recipe.mealType else { continue }
            usageCounts[ObjectIdentifier(mealType), default: 0] += 1
        }

        for portion in portions {
            guard let mealType = portion.mealType else { continue }
            usageCounts[ObjectIdentifier(mealType), default: 0] += 1
        }

        return usageCounts
    }

    private static func measurementUnitUsageCounts(
        recipeIngredients: [RecipeIngredient]
    ) -> [ObjectIdentifier: Int] {
        var usageCounts: [ObjectIdentifier: Int] = [:]

        for recipeIngredient in recipeIngredients {
            guard let unit = recipeIngredient.unit else { continue }
            usageCounts[ObjectIdentifier(unit), default: 0] += 1
        }

        return usageCounts
    }

    private static func survivor(
        in mealTypes: [MealType],
        usageCounts: [ObjectIdentifier: Int]
    ) -> MealType {
        mealTypes.sorted { lhs, rhs in
            let lhsUsageCount = usageCounts[ObjectIdentifier(lhs), default: 0]
            let rhsUsageCount = usageCounts[ObjectIdentifier(rhs), default: 0]
            if lhsUsageCount != rhsUsageCount {
                return lhsUsageCount > rhsUsageCount
            }

            let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }[0]
    }

    private static func survivor(
        in units: [MeasurementUnit],
        usageCounts: [ObjectIdentifier: Int]
    ) -> MeasurementUnit {
        units.sorted { lhs, rhs in
            let lhsUsageCount = usageCounts[ObjectIdentifier(lhs), default: 0]
            let rhsUsageCount = usageCounts[ObjectIdentifier(rhs), default: 0]
            if lhsUsageCount != rhsUsageCount {
                return lhsUsageCount > rhsUsageCount
            }

            let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            let symbolComparison = lhs.symbol.localizedCaseInsensitiveCompare(rhs.symbol)
            if symbolComparison != .orderedSame {
                return symbolComparison == .orderedAscending
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }[0]
    }

    private static func reassignRecipes(
        _ recipes: [Recipe],
        replacementsByObjectID: [ObjectIdentifier: MealType]
    ) -> Bool {
        var changed = false

        for recipe in recipes {
            guard let mealType = recipe.mealType,
                  let replacement = replacementsByObjectID[ObjectIdentifier(mealType)] else {
                continue
            }

            recipe.mealType = replacement
            changed = true
        }

        return changed
    }

    private static func reassignPlannedMealPortions(
        _ portions: [PlannedMealPortion],
        replacementsByObjectID: [ObjectIdentifier: MealType]
    ) -> Bool {
        var changed = false

        for portion in portions {
            guard let mealType = portion.mealType,
                  let replacement = replacementsByObjectID[ObjectIdentifier(mealType)] else {
                continue
            }

            portion.mealType = replacement
            changed = true
        }

        return changed
    }

    private static func reassignRecipeIngredientUnits(
        _ recipeIngredients: [RecipeIngredient],
        replacementsByObjectID: [ObjectIdentifier: MeasurementUnit]
    ) -> Bool {
        var changed = false

        for recipeIngredient in recipeIngredients {
            guard let unit = recipeIngredient.unit,
                  let replacement = replacementsByObjectID[ObjectIdentifier(unit)] else {
                continue
            }

            recipeIngredient.unit = replacement
            changed = true
        }

        return changed
    }

    private static func repairExcludedCalendarMealTypeIDs(
        replacementIDsByRemovedID: [UUID: UUID]
    ) -> Bool {
        let defaults = FoodBasketSharedContainer.userDefaults
        let key = "calendarViewExcludedMealTypeIDs"
        let rawValue = FoodBasketSharedContainer.string(forKey: key) ?? ""
        var ids = Set(
            rawValue
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
        )
        guard !ids.isEmpty else { return false }

        var changed = false
        for (removedID, replacementID) in replacementIDsByRemovedID
        where ids.contains(removedID) {
            ids.remove(removedID)
            ids.insert(replacementID)
            changed = true
        }

        guard changed else { return false }

        defaults.set(
            ids.map(\.uuidString).sorted().joined(separator: ","),
            forKey: key
        )
        return true
    }
}
