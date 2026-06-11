//
//  GetDinnerPlanIntent.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import AppIntents
import SwiftUI

struct GetDinnerPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Get This Week's Dinner Plan"
    static let description = IntentDescription("Reads the dinners planned for this week.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        let dinnerPlan = try CurrentWeekPlanReader().dinnerPlan()
        return .result(value: dinnerPlan.summary, dialog: "\(dinnerPlan.summary)") {
            DinnerPlanSnippetView(mealNames: dinnerPlan.mealNames)
        }
    }
}
