//
//  AppIntent.swift
//  FoodBasketWidgetExtension
//
//  Created by Logan Janssen | Codify on 11/6/2026.
//

import AppIntents
import Foundation

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Next Meal" }
    static var description: IntentDescription { "Choose which meal type this widget should show." }

    @Parameter(
        title: "Meal Type",
        default: "All",
        optionsProvider: FoodBasketWidgetMealTypeOptionsProvider()
    )
    var mealType: String
}

struct FoodBasketWidgetMealTypeOptionsProvider: DynamicOptionsProvider {
    static let allMealTypesTitle = "All"

    func results() async throws -> [String] {
        let mealTypeNames = FoodBasketWidgetSnapshotStore.load()?.plannedMeals
            .compactMap(\.mealTypeName)
            .filter { !$0.isEmpty } ?? []
        let sortedNames = Set(mealTypeNames).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        return [Self.allMealTypesTitle] + sortedNames
    }
}

struct FoodBasketWidgetPlanSnapshot: Codable, Equatable {
    var generatedAt: Date
    var weekStarting: Date
    var dinnerMealNames: [String]
    var groceryLines: [FoodBasketWidgetGroceryLine]
    var plannedMeals: [FoodBasketWidgetPlannedMeal]
}

struct FoodBasketWidgetPlannedMeal: Codable, Equatable, Identifiable {
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

struct FoodBasketWidgetGroceryLine: Codable, Equatable {
    let ingredientID: UUID
    let ingredientName: String
    let categoryName: String
    var unitSymbol: String
    var quantity: Double
    var recipeUsages: [FoodBasketWidgetRecipeUsage]
}

struct FoodBasketWidgetRecipeUsage: Codable, Equatable {
    let recipeID: UUID
    let recipeName: String
    var quantity: Double
    var unitSymbol: String
    var firstSortOrder: Int
}

enum FoodBasketWidgetSnapshotStore {
    private static let appGroupIdentifier = "group.com.logan.FoodBasket"
    private static let fileName = "CurrentPlanSnapshot.json"

    static func load() -> FoodBasketWidgetPlanSnapshot? {
        guard let fileURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent(fileName) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(FoodBasketWidgetPlanSnapshot.self, from: data)
        } catch {
            return nil
        }
    }
}
