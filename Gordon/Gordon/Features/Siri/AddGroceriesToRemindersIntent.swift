//
//  AddGroceriesToRemindersIntent.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import AppIntents
import SwiftUI

struct AddGroceriesToRememberedRemindersListIntent: AppIntent {
    static let title: LocalizedStringResource = "Add This Week's Groceries to Reminders"
    static let description = IntentDescription(
        "Adds the groceries for this week's meal plan to the most recently used Reminders list."
    )
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog & ShowsSnippetView {
        let lines = try CurrentWeekPlanReader().shoppingListLines()

        guard !lines.isEmpty else {
            return .result(
                value: 0,
                dialog: "There aren't any groceries planned for this week."
            ) {
                GroceryExportSnippetView(lines: [])
            }
        }

        guard let rememberedList = ReminderListDefaults.rememberedList else {
            throw RemindersExportError.noRememberedList
        }

        try await RemindersExporter().export(lines, to: rememberedList)
        return .result(
            value: lines.count,
            dialog: "\(lines.count) grocery items were added to \(rememberedList.title)."
        ) {
            GroceryExportSnippetView(
                listTitle: rememberedList.title,
                lines: lines
            )
        }
    }
}
