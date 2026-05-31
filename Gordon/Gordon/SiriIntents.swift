//
//  SiriIntents.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import AppIntents
import Foundation
import SwiftData

struct GetDinnerPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Get This Week's Dinner Plan"
    static let description = IntentDescription("Reads the dinners planned for this week.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = try CurrentWeekPlanReader().dinnerSummary()
        return .result(value: summary, dialog: "\(summary)")
    }
}

struct AddGroceriesToRememberedRemindersListIntent: AppIntent {
    static let title: LocalizedStringResource = "Add This Week's Groceries to Reminders"
    static let description = IntentDescription(
        "Adds the groceries for this week's meal plan to the most recently used Reminders list."
    )
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let lines = try CurrentWeekPlanReader().shoppingListLines()

        guard !lines.isEmpty else {
            return .result(
                value: 0,
                dialog: "There aren't any groceries planned for this week."
            )
        }

        guard let rememberedList = ReminderListDefaults.rememberedList else {
            throw RemindersExportError.noRememberedList
        }

        try await RemindersExporter().export(lines, to: rememberedList)
        return .result(
            value: lines.count,
            dialog: "\(lines.count) grocery items were added to \(rememberedList.title)."
        )
    }
}

struct GordonShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetDinnerPlanIntent(),
            phrases: [
                "What's for dinner this week in \(.applicationName)",
                "What am I having for dinner this week in \(.applicationName)",
                "Read my meal plan in \(.applicationName)",
            ],
            shortTitle: "This Week's Dinners",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: AddGroceriesToRememberedRemindersListIntent(),
            phrases: [
                "Add this week's groceries from \(.applicationName) to Reminders",
                "Add my \(.applicationName) grocery list to Reminders",
            ],
            shortTitle: "Add Groceries to Reminders",
            systemImageName: "checklist"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .lime
}

@MainActor
private struct CurrentWeekPlanReader {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer? = nil) {
        modelContext = (modelContainer ?? GordonModelContainer.shared).mainContext
    }

    func dinnerSummary() throws -> String {
        let names = try currentPlan()?
            .plannedMeals
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap(\.recipe?.name) ?? []

        guard !names.isEmpty else {
            return "You don't have any dinners planned this week."
        }

        return "This week you have \(ListFormatter.localizedString(byJoining: names))."
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
