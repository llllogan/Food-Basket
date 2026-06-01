//
//  WeekPlan.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import Foundation
import SwiftData

@Model
final class WeekPlan {
    @Attribute(.unique) var id: UUID
    var weekStarting: Date

    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.weekPlan)
    var plannedMeals: [PlannedMeal]

    init(
        id: UUID = UUID(),
        weekStarting: Date,
        plannedMeals: [PlannedMeal] = []
    ) {
        self.id = id
        self.weekStarting = weekStarting
        self.plannedMeals = plannedMeals
    }
}

@Model
final class PlannedMeal {
    @Attribute(.unique) var id: UUID
    var quantityMultiplier: Double
    var sortOrder: Int
    var weekPlan: WeekPlan?
    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        quantityMultiplier: Double = 1,
        sortOrder: Int = 0,
        weekPlan: WeekPlan? = nil,
        recipe: Recipe? = nil
    ) {
        self.id = id
        self.quantityMultiplier = quantityMultiplier
        self.sortOrder = sortOrder
        self.weekPlan = weekPlan
        self.recipe = recipe
    }
}
