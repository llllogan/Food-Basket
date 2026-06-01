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
    let sharedModelContainer = FoodBasketModelContainer.shared

    init() {
        FoodBasketShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
