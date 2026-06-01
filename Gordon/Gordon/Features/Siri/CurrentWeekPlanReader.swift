//
//  CurrentWeekPlanReader.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import Foundation
import SwiftData

@MainActor
struct CurrentWeekPlanReader {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer? = nil) {
        modelContext = (modelContainer ?? GordonModelContainer.shared).mainContext
    }

    func dinnerPlan() throws -> DinnerPlanResult {
        let recipes = try currentPlan()?
            .plannedMeals
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap(\.recipe) ?? []
        return DinnerPlanResult(
            mealNames: recipes.map(\.name),
            recipePhotoData: recipes.map(\.photoData)
        )
    }

    func shoppingListLines() throws -> [ShoppingListLine] {
        ShoppingListLine.makeLines(for: try currentPlan())
    }

    private func currentPlan() throws -> WeekPlan? {
        let weekStarting = Calendar.current.startOfWeek(containing: Date())
        return try modelContext.fetch(FetchDescriptor<WeekPlan>()).first {
            Calendar.current.isDate($0.weekStarting, inSameDayAs: weekStarting)
        }
    }
}

struct DinnerPlanResult {
    let mealNames: [String]
    let recipePhotoData: [Data?]

    var summary: String {
        guard !mealNames.isEmpty else {
            return "You don't have any dinners planned this week."
        }

        return "This week you have \(ListFormatter.localizedString(byJoining: mealNames))."
    }
}
