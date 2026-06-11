//
//  CurrentWeekPlanReader.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import Foundation
import SwiftData

@MainActor
struct CurrentWeekPlanReader {
    private let modelContainer: ModelContainer?

    init(modelContainer: ModelContainer? = nil) {
        self.modelContainer = modelContainer
    }

    func dinnerPlan() throws -> DinnerPlanResult {
        let snapshot = try currentSnapshot()
        return DinnerPlanResult(
            mealNames: snapshot.dinnerMealNames
        )
    }

    func shoppingListLines() throws -> [FoodBasketPlanSnapshotGroceryLine] {
        try currentSnapshot().groceryLines
    }

    func currentSnapshot() throws -> FoodBasketPlanSnapshot {
        let existingSnapshot = FoodBasketPlanSnapshotStore.loadCurrentWeek()

        do {
            let container = try modelContainer ?? FoodBasketModelContainer.make()
            let refreshedSnapshot = try FoodBasketPlanSnapshotStore.refresh(in: container.mainContext)

            if refreshedSnapshot.dinnerMealNames.isEmpty,
               let existingSnapshot,
               !existingSnapshot.dinnerMealNames.isEmpty {
                return existingSnapshot
            }

            return refreshedSnapshot
        } catch {
            if let existingSnapshot {
                return existingSnapshot
            }

            throw error
        }
    }
}

struct DinnerPlanResult {
    let mealNames: [String]

    var summary: String {
        guard !mealNames.isEmpty else {
            return "You don't have any dinners planned this week."
        }

        return "This week you have \(ListFormatter.localizedString(byJoining: mealNames))."
    }
}
