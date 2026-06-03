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
    private static let cloudKitContainerIdentifier = "iCloud.com.logan.FoodBasket"

    static let shared = make()

    static func make(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        let schema = FoodBasketDataSchema.current
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: isStoredInMemoryOnly
                ? .none
                : .private(cloudKitContainerIdentifier)
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
                containerIdentifier: cloudKitContainerIdentifier
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
}
