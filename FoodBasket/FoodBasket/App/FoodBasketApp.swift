//
//  FoodBasketApp.swift
//  Food Basket
//
//  Created by Logan Janssen | Codify on 31/5/2026.
//

import AppIntents
import SwiftData
import SwiftUI

@main
struct FoodBasketApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer: ModelContainer
    #if DEBUG
    private let screenshotConfiguration: FoodBasketScreenshotConfiguration
    private let previewData: PreviewData?
    #endif

    init() {
        Self.migrateSharedDefaultsIfNeeded()

        #if DEBUG
        screenshotConfiguration = FoodBasketScreenshotConfiguration()
        if screenshotConfiguration.usesPreviewData {
            let previewData = PreviewData()
            self.previewData = previewData
            sharedModelContainer = previewData.container
        } else {
            previewData = nil
            sharedModelContainer = FoodBasketModelContainer.shared
        }
        #else
        sharedModelContainer = FoodBasketModelContainer.shared
        #endif

        FoodBasketShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .task {
                    IngredientEnrichmentScheduler.schedulePendingIngredientEnrichment(
                        in: sharedModelContainer.mainContext
                    )
                    refreshPlanSnapshot()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        IngredientEnrichmentScheduler.schedulePendingIngredientEnrichment(
                            in: sharedModelContainer.mainContext
                        )
                        refreshPlanSnapshot()
                    case .background:
                        refreshPlanSnapshot()
                        IngredientEnrichmentScheduler.cancelPendingIngredientEnrichment()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
        .defaultAppStorage(FoodBasketSharedContainer.userDefaults)
        .modelContainer(sharedModelContainer)
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        ContentView(
            selectedTab: screenshotConfiguration.selectedTab,
            selectedWeekPlanMode: screenshotConfiguration.selectedWeekPlanMode,
            selectedRecipeID: screenshotConfiguration.selectedRecipeID(in: previewData)
        )
        #else
        ContentView()
        #endif
    }

    private static func migrateSharedDefaultsIfNeeded() {
        FoodBasketSharedContainer.migrateLegacyDefaultsIfNeeded(keys: [
            CalendarListDefaults.idKey,
            CalendarListDefaults.nameKey,
            CalendarListDefaults.sourceTitleKey,
            CalendarSyncDefaults.isEnabledKey,
            CalendarSyncDefaults.calendarIDKey,
            CalendarSyncDefaults.calendarNameKey,
            CalendarSyncDefaults.calendarSourceTitleKey,
            ReminderListDefaults.idKey,
            ReminderListDefaults.nameKey,
            "calendarViewExcludedMealTypeIDs",
            "calendarViewExcludeMealsWithoutMealType",
            "isGroceryListReminderExportTipComplete",
            "groceryListReminderExportTipVisibleSeconds",
            "removeMealsAtStartOfNewWeek",
            "mealCleanupWeekStartDay",
            "ingredientListOrganiseMode",
            IngredientImagePromptDefaults.templateKey,
        ])
    }

    private func refreshPlanSnapshot() {
        if (try? FoodBasketPlanSnapshotStore.refresh(in: sharedModelContainer.mainContext)) != nil {
            FoodBasketWidgetTimelineReloader.reloadTimelines()
        }
    }
}

#if DEBUG
private struct FoodBasketScreenshotConfiguration {
    let usesPreviewData: Bool
    let selectedTab: FoodBasketTab
    let selectedWeekPlanMode: WeekPlanDisplayMode
    private let opensPreviewRecipe: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesPreviewData = Self.booleanValue(
            for: "-FoodBasketUsePreviewData",
            in: arguments
        )
        selectedTab = Self.tabValue(
            for: "-FoodBasketScreenshotTab",
            in: arguments
        ) ?? .recipes
        selectedWeekPlanMode = Self.weekPlanModeValue(
            for: "-FoodBasketScreenshotWeekPlanMode",
            in: arguments
        ) ?? .list
        opensPreviewRecipe = Self.booleanValue(
            for: "-FoodBasketScreenshotOpenRecipe",
            in: arguments
        )
    }

    func selectedRecipeID(in previewData: PreviewData?) -> UUID? {
        guard opensPreviewRecipe else { return nil }
        return previewData?.recipe.id
    }

    private static func booleanValue(
        for key: String,
        in arguments: [String]
    ) -> Bool {
        guard let value = value(after: key, in: arguments) else {
            return arguments.contains(key)
        }

        return ["1", "true", "yes"].contains(value.lowercased())
    }

    private static func tabValue(
        for key: String,
        in arguments: [String]
    ) -> FoodBasketTab? {
        switch value(after: key, in: arguments)?.lowercased() {
        case "recipes":
            .recipes
        case "weekplan", "week-plan", "thisweek", "this-week":
            .weekPlan
        case "ingredients":
            .ingredients
        case "settings":
            .settings
        default:
            nil
        }
    }

    private static func weekPlanModeValue(
        for key: String,
        in arguments: [String]
    ) -> WeekPlanDisplayMode? {
        switch value(after: key, in: arguments)?.lowercased() {
        case "list", "meals":
            .list
        case "calendar":
            .calendar
        case "grocerylist", "grocery-list", "groceries":
            .groceryList
        default:
            nil
        }
    }

    private static func value(
        after key: String,
        in arguments: [String]
    ) -> String? {
        guard let index = arguments.firstIndex(of: key) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}
#endif
