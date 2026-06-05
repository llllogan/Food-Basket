//
//  FoodBasketModelContainer.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import CoreData
import Foundation
import SwiftData

@MainActor
enum FoodBasketModelContainer {
    static let shared = make()

    static func make(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        let schema = FoodBasketDataSchema.current
        migrateDefaultStoreToSharedContainerIfNeeded(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        let configuration = modelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            usesSharedContainer: true
        )

        do {
            #if DEBUG
            if !isStoredInMemoryOnly && UserDefaults.standard.bool(forKey: "InitializeCloudKitSchema") {
                try initializeDevelopmentCloudKitSchema(
                    schema: schema,
                    configuration: configuration
                )
            }
            #endif

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    #if DEBUG
    private static func initializeDevelopmentCloudKitSchema(
        schema: Schema,
        configuration: ModelConfiguration
    ) throws {
        try autoreleasepool {
            let description = NSPersistentStoreDescription(url: configuration.url)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: FoodBasketSharedContainer.cloudKitContainerIdentifier
            )
            description.shouldAddStoreAsynchronously = false

            guard let managedObjectModel = NSManagedObjectModel.makeManagedObjectModel(for: schema) else {
                fatalError("Could not create managed object model for CloudKit schema initialization.")
            }

            let container = NSPersistentCloudKitContainer(
                name: "Food Basket",
                managedObjectModel: managedObjectModel
            )
            container.persistentStoreDescriptions = [description]
            container.loadPersistentStores { _, error in
                if let error {
                    fatalError("Could not load store for CloudKit schema initialization: \(error)")
                }
            }

            try container.initializeCloudKitSchema()

            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }
    #endif

    private static func modelConfiguration(
        schema: Schema,
        isStoredInMemoryOnly: Bool,
        usesSharedContainer: Bool
    ) -> ModelConfiguration {
        guard !isStoredInMemoryOnly else {
            return ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        }

        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: usesSharedContainer
                ? .identifier(FoodBasketSharedContainer.appGroupIdentifier)
                : .automatic,
            cloudKitDatabase: .private(FoodBasketSharedContainer.cloudKitContainerIdentifier)
        )
    }

    private static func migrateDefaultStoreToSharedContainerIfNeeded(
        schema: Schema,
        isStoredInMemoryOnly: Bool
    ) {
        let sharedStoreURL = modelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            usesSharedContainer: true
        ).url

        guard !isStoredInMemoryOnly,
              !FileManager.default.fileExists(atPath: sharedStoreURL.path) else {
            return
        }

        let defaultConfiguration = modelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            usesSharedContainer: false
        )
        let defaultStoreURL = defaultConfiguration.url

        guard defaultStoreURL != sharedStoreURL,
              FileManager.default.fileExists(atPath: defaultStoreURL.path) else {
            return
        }

        copyStoreFileIfPresent(from: defaultStoreURL, to: sharedStoreURL)
        copyStoreFileIfPresent(
            from: sqliteSidecarURL(for: defaultStoreURL, suffix: "-shm"),
            to: sqliteSidecarURL(for: sharedStoreURL, suffix: "-shm")
        )
        copyStoreFileIfPresent(
            from: sqliteSidecarURL(for: defaultStoreURL, suffix: "-wal"),
            to: sqliteSidecarURL(for: sharedStoreURL, suffix: "-wal")
        )
    }

    private static func sqliteSidecarURL(for storeURL: URL, suffix: String) -> URL {
        URL(fileURLWithPath: storeURL.path + suffix)
    }

    private static func copyStoreFileIfPresent(from sourceURL: URL, to destinationURL: URL) {
        guard FileManager.default.fileExists(atPath: sourceURL.path),
              !FileManager.default.fileExists(atPath: destinationURL.path) else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            // If the old local store cannot be copied, SwiftData can still create/open
            // the shared store and CloudKit can repopulate it.
        }
    }
}
