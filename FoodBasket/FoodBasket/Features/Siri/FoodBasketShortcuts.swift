//
//  FoodBasketShortcuts.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import AppIntents

struct FoodBasketShortcuts: AppShortcutsProvider {
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
