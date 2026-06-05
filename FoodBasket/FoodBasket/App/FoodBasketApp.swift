//
//  FoodBasketApp.swift
//  Food Basket
//
//  Created by Logan Janssen | Codify on 31/5/2026.
//

import AppIntents
import SwiftData
import SwiftUI
import TipKit

@main
struct FoodBasketApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer = FoodBasketModelContainer.shared

    init() {
        try? Tips.configure()
        FoodBasketShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    IngredientEnrichmentScheduler.schedulePendingIngredientEnrichment(
                        in: sharedModelContainer.mainContext
                    )
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        IngredientEnrichmentScheduler.schedulePendingIngredientEnrichment(
                            in: sharedModelContainer.mainContext
                        )
                    case .background:
                        IngredientEnrichmentScheduler.cancelPendingIngredientEnrichment()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
