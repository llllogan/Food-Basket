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
    let sharedModelContainer = FoodBasketModelContainer.shared

    init() {
        try? Tips.configure()
        FoodBasketShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
