//
//  WeekPlan.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

@Model
final class WeekPlan {
    var id: UUID = UUID()
    var weekStarting: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.weekPlan)
    var plannedMeals: [PlannedMeal]? = []

    @Relationship(deleteRule: .cascade, inverse: \PlannedMealPortion.weekPlan)
    var plannedMealPortions: [PlannedMealPortion]? = []

    init(
        id: UUID = UUID(),
        weekStarting: Date,
        plannedMeals: [PlannedMeal]? = [],
        plannedMealPortions: [PlannedMealPortion]? = []
    ) {
        self.id = id
        self.weekStarting = weekStarting
        self.plannedMeals = plannedMeals
        self.plannedMealPortions = plannedMealPortions
    }
}

@Model
final class PlannedMeal {
    var id: UUID = UUID()
    var quantityMultiplier: Double = 1
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var weekPlan: WeekPlan?
    var recipe: Recipe?

    @Relationship(deleteRule: .cascade, inverse: \PlannedMealPortion.plannedMeal)
    var portions: [PlannedMealPortion]? = []

    init(
        id: UUID = UUID(),
        quantityMultiplier: Double = 1,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        weekPlan: WeekPlan? = nil,
        recipe: Recipe? = nil,
        portions: [PlannedMealPortion]? = []
    ) {
        self.id = id
        self.quantityMultiplier = quantityMultiplier
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.weekPlan = weekPlan
        self.recipe = recipe
        self.portions = portions
    }
}

@Model
final class PlannedMealPortion {
    var id: UUID = UUID()
    var dayOffset: Int = 0
    var sortOrder: Int = 0
    var weekPlan: WeekPlan?
    var plannedMeal: PlannedMeal?
    var mealType: MealType?

    init(
        id: UUID = UUID(),
        dayOffset: Int = 0,
        sortOrder: Int = 0,
        weekPlan: WeekPlan? = nil,
        plannedMeal: PlannedMeal? = nil,
        mealType: MealType? = nil
    ) {
        self.id = id
        self.dayOffset = dayOffset
        self.sortOrder = sortOrder
        self.weekPlan = weekPlan
        self.plannedMeal = plannedMeal
        self.mealType = mealType
    }
}

extension PlannedMealPortion {
    static func portionCount(for plannedMeal: PlannedMeal) -> Int {
        let serves = max(plannedMeal.recipe?.serves ?? 1, 1)
        let count = Double(serves) * max(plannedMeal.quantityMultiplier, 0)
        return max(Int(count.rounded(.toNearestOrAwayFromZero)), 1)
    }
}
