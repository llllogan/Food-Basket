//
//  FoodBasketSharedContainer.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation

enum FoodBasketSharedContainer {
    static let appGroupIdentifier = "group.com.logan.FoodBasket"
    static let cloudKitContainerIdentifier = "iCloud.com.logan.FoodBasket"

    static var appGroupURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func bool(forKey key: String) -> Bool {
        let sharedDefaults = userDefaults
        if sharedDefaults.object(forKey: key) != nil {
            return sharedDefaults.bool(forKey: key)
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    static func integer(forKey key: String) -> Int {
        let sharedDefaults = userDefaults
        if sharedDefaults.object(forKey: key) != nil {
            return sharedDefaults.integer(forKey: key)
        }

        return UserDefaults.standard.integer(forKey: key)
    }

    static func string(forKey key: String) -> String? {
        userDefaults.string(forKey: key) ?? UserDefaults.standard.string(forKey: key)
    }

    static func migrateLegacyDefaultsIfNeeded(keys: [String]) {
        let sharedDefaults = userDefaults
        let legacyDefaults = UserDefaults.standard

        guard sharedDefaults !== legacyDefaults else { return }

        for key in keys where sharedDefaults.object(forKey: key) == nil {
            guard let value = legacyDefaults.object(forKey: key) else { continue }
            sharedDefaults.set(value, forKey: key)
        }
    }
}
