//
//  GordonApp.swift
//  Gordon
//
//  Created by Logan Janssen | Codify on 31/5/2026.
//

import AppIntents
import SwiftData
import SwiftUI

@main
struct GordonApp: App {
    let sharedModelContainer = GordonModelContainer.shared

    init() {
        GordonShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
