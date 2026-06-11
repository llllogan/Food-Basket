//
//  FoodBasketPlanSnapshot.swift
//  Food Basket
//
//  Created by Codex on 11/6/2026.
//

import Foundation
import SwiftData
import UIKit

struct FoodBasketPlanSnapshot: Codable, Equatable {
    var generatedAt: Date
    var weekStarting: Date
    var dinnerMealNames: [String]
    var groceryLines: [FoodBasketPlanSnapshotGroceryLine]
    var plannedMeals: [FoodBasketPlanSnapshotPlannedMeal]

    static func empty(weekStarting: Date = WeekStartDay.foodBasketCalendarStartDay().startOfWeek(containing: Date())) -> FoodBasketPlanSnapshot {
        FoodBasketPlanSnapshot(
            generatedAt: Date(),
            weekStarting: weekStarting,
            dinnerMealNames: [],
            groceryLines: [],
            plannedMeals: []
        )
    }

    var dinnerSummary: String {
        guard !dinnerMealNames.isEmpty else {
            return "You don't have any dinners planned this week."
        }

        return "This week you have \(ListFormatter.localizedString(byJoining: dinnerMealNames))."
    }
}

struct FoodBasketPlanSnapshotPlannedMeal: Codable, Equatable, Identifiable {
    let id: UUID
    let recipeID: UUID
    let recipeName: String
    let plannedDate: Date
    let dayOffset: Int
    let mealSortOrder: Int
    let portionSortOrder: Int
    let mealTypeID: UUID?
    let mealTypeName: String?
    let imageData: Data?
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
                .map(FoodBasketPlanSnapshotGroceryLine.init),
            plannedMeals: try plannedMealSnapshots(
                for: plan,
                in: modelContext,
                weekStarting: weekStarting
            )
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

    private static func plannedMealSnapshots(
        for plan: WeekPlan?,
        in modelContext: ModelContext,
        weekStarting: Date
    ) throws -> [FoodBasketPlanSnapshotPlannedMeal] {
        guard let plan else { return [] }

        let planID = plan.id
        let descriptor = FetchDescriptor<PlannedMealPortion>(
            predicate: #Predicate {
                $0.weekPlan?.id == planID || $0.plannedMeal?.weekPlan?.id == planID
            },
            sortBy: [
                SortDescriptor(\PlannedMealPortion.dayOffset),
                SortDescriptor(\PlannedMealPortion.sortOrder),
            ]
        )
        let portions = try modelContext.fetch(descriptor)
        let sourcePortions = portions.isEmpty ? fallbackPortions(for: plan) : portions

        return sourcePortions.compactMap { portion in
            guard let plannedMeal = portion.plannedMeal,
                  let recipe = plannedMeal.recipe else {
                return nil
            }

            let mealType = portion.mealType ?? recipe.mealType
            let plannedDate = calendar.date(
                byAdding: .day,
                value: portion.dayOffset,
                to: weekStarting
            ) ?? weekStarting

            return FoodBasketPlanSnapshotPlannedMeal(
                id: portion.id,
                recipeID: recipe.id,
                recipeName: recipe.name,
                plannedDate: plannedDate,
                dayOffset: portion.dayOffset,
                mealSortOrder: plannedMeal.sortOrder,
                portionSortOrder: portion.sortOrder,
                mealTypeID: mealType?.id,
                mealTypeName: mealType?.name,
                imageData: widgetImageData(from: recipe.photoData)
            )
        }
    }

    private static func fallbackPortions(for plan: WeekPlan) -> [PlannedMealPortion] {
        (plan.plannedMeals ?? []).enumerated().map { index, meal in
            PlannedMealPortion(
                dayOffset: 0,
                sortOrder: index,
                weekPlan: plan,
                plannedMeal: meal,
                mealType: meal.recipe?.mealType
            )
        }
    }

    private static func widgetImageData(from sourceData: Data?) -> Data? {
        guard let sourceData,
              let image = UIImage(data: sourceData) else {
            return nil
        }

        let maxDimension: CGFloat = 900
        let largestDimension = max(image.size.width, image.size.height)
        let scaledImage: UIImage

        if largestDimension > maxDimension {
            let scale = maxDimension / largestDimension
            let targetSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            scaledImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            scaledImage = image
        }

        return scaledImage.jpegData(compressionQuality: 0.72)
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
