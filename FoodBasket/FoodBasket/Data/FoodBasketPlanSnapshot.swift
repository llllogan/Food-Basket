//
//  FoodBasketPlanSnapshot.swift
//  Food Basket
//
//  Created by Codex on 11/6/2026.
//

import Foundation
import SwiftData

struct FoodBasketPlanSnapshot: Codable, Equatable {
    var generatedAt: Date
    var weekStarting: Date
    var dinnerMealNames: [String]
    var groceryLines: [FoodBasketPlanSnapshotGroceryLine]

    static func empty(weekStarting: Date = WeekStartDay.foodBasketCalendarStartDay().startOfWeek(containing: Date())) -> FoodBasketPlanSnapshot {
        FoodBasketPlanSnapshot(
            generatedAt: Date(),
            weekStarting: weekStarting,
            dinnerMealNames: [],
            groceryLines: []
        )
    }

    var dinnerSummary: String {
        guard !dinnerMealNames.isEmpty else {
            return "You don't have any dinners planned this week."
        }

        return "This week you have \(ListFormatter.localizedString(byJoining: dinnerMealNames))."
    }
}

struct FoodBasketPlanSnapshotGroceryLine: Codable, Equatable, Identifiable {
    let ingredientID: UUID
    let ingredientName: String
    let categoryName: String
    var unitSymbol: String
    var quantity: Double
    var recipeUsages: [FoodBasketPlanSnapshotRecipeUsage]

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

    init(
        ingredientID: UUID,
        ingredientName: String,
        categoryName: String,
        unitSymbol: String,
        quantity: Double,
        recipeUsages: [FoodBasketPlanSnapshotRecipeUsage] = []
    ) {
        self.ingredientID = ingredientID
        self.ingredientName = ingredientName
        self.categoryName = categoryName
        self.unitSymbol = unitSymbol
        self.quantity = quantity
        self.recipeUsages = recipeUsages
    }

    init(_ line: ShoppingListLine) {
        self.init(
            ingredientID: line.ingredientID,
            ingredientName: line.ingredientName,
            categoryName: line.categoryName,
            unitSymbol: line.unitSymbol,
            quantity: line.quantity,
            recipeUsages: line.recipeUsages.map(FoodBasketPlanSnapshotRecipeUsage.init)
        )
    }
}

struct FoodBasketPlanSnapshotRecipeUsage: Codable, Equatable {
    let recipeID: UUID
    let recipeName: String
    var quantity: Double
    var unitSymbol: String
    var firstSortOrder: Int

    init(
        recipeID: UUID,
        recipeName: String,
        quantity: Double,
        unitSymbol: String,
        firstSortOrder: Int
    ) {
        self.recipeID = recipeID
        self.recipeName = recipeName
        self.quantity = quantity
        self.unitSymbol = unitSymbol
        self.firstSortOrder = firstSortOrder
    }

    init(_ usage: ShoppingListRecipeUsage) {
        self.init(
            recipeID: usage.recipeID,
            recipeName: usage.recipeName,
            quantity: usage.quantity,
            unitSymbol: usage.unitSymbol,
            firstSortOrder: usage.firstSortOrder
        )
    }
}

@MainActor
enum FoodBasketPlanSnapshotStore {
    private static let fileName = "CurrentPlanSnapshot.json"
    private static let calendar = Calendar.current

    static func loadCurrentWeek() -> FoodBasketPlanSnapshot? {
        guard let snapshot = load(),
              calendar.isDate(
                snapshot.weekStarting,
                inSameDayAs: currentWeekStarting
              ) else {
            return nil
        }

        return snapshot
    }

    static func load() -> FoodBasketPlanSnapshot? {
        guard let fileURL else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(FoodBasketPlanSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    @discardableResult
    static func refresh(in modelContext: ModelContext) throws -> FoodBasketPlanSnapshot {
        let snapshot = try makeSnapshot(in: modelContext)
        try save(snapshot)
        return snapshot
    }

    static func save(_ snapshot: FoodBasketPlanSnapshot) throws {
        guard let fileURL else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    static func makeSnapshot(in modelContext: ModelContext) throws -> FoodBasketPlanSnapshot {
        let weekStarting = currentWeekStarting
        let plan = try currentPlan(in: modelContext, weekStarting: weekStarting)
        let meals = try plannedMeals(for: plan, in: modelContext)
        let mealNames = meals
            .compactMap(\.recipe)
            .map(\.name)

        return FoodBasketPlanSnapshot(
            generatedAt: Date(),
            weekStarting: weekStarting,
            dinnerMealNames: mealNames,
            groceryLines: ShoppingListLine.makeLines(for: meals)
                .map(FoodBasketPlanSnapshotGroceryLine.init)
        )
    }

    private static func currentPlan(
        in modelContext: ModelContext,
        weekStarting: Date
    ) throws -> WeekPlan? {
        let nextDayStarting = calendar.date(
            byAdding: .day,
            value: 1,
            to: weekStarting
        ) ?? weekStarting.addingTimeInterval(24 * 60 * 60)

        var descriptor = FetchDescriptor<WeekPlan>(
            predicate: #Predicate {
                $0.weekStarting >= weekStarting && $0.weekStarting < nextDayStarting
            },
            sortBy: [SortDescriptor(\WeekPlan.weekStarting)]
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private static func plannedMeals(
        for plan: WeekPlan?,
        in modelContext: ModelContext
    ) throws -> [PlannedMeal] {
        guard let plan else { return [] }

        let planID = plan.id
        let descriptor = FetchDescriptor<PlannedMeal>(
            predicate: #Predicate {
                $0.weekPlan?.id == planID
            },
            sortBy: [
                SortDescriptor(\PlannedMeal.sortOrder),
                SortDescriptor(\PlannedMeal.createdAt),
            ]
        )
        let meals = try modelContext.fetch(descriptor)

        guard meals.isEmpty else { return meals }

        return (plan.plannedMeals ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private static var currentWeekStarting: Date {
        WeekStartDay.foodBasketCalendarStartDay()
            .startOfWeek(containing: Date(), calendar: calendar)
    }

    private static var fileURL: URL? {
        FoodBasketSharedContainer.appGroupURL?
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
