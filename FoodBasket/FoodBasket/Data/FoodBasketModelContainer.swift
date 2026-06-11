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
    static let shared = makeOrFallback()

    static func makeOrFallback(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        do {
            return try make(isStoredInMemoryOnly: isStoredInMemoryOnly)
        } catch {
            assertionFailure("Could not create ModelContainer: \(error)")
            return makeFallbackContainer()
        }
    }

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
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
            if !isStoredInMemoryOnly && FoodBasketSharedContainer.bool(forKey: "InitializeCloudKitSchema") {
                try initializeDevelopmentCloudKitSchema(
                    schema: schema,
                    configuration: configuration
                )
            }
            #endif

            return try ModelContainer(
                for: schema,
                migrationPlan: FoodBasketDataMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            throw FoodBasketModelContainerError.containerCreationFailed(error)
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
                throw FoodBasketModelContainerError.managedObjectModelUnavailable
            }

            let container = NSPersistentCloudKitContainer(
                name: "Food Basket",
                managedObjectModel: managedObjectModel
            )
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in
                loadError = error
            }

            if let loadError {
                throw FoodBasketModelContainerError.cloudKitSchemaStoreLoadFailed(loadError)
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

        copyStoreRelatedFilesIfPresent(from: defaultStoreURL, to: sharedStoreURL)
    }

    private static func copyStoreRelatedFilesIfPresent(from sourceURL: URL, to destinationURL: URL) {
        let sourceDirectory = sourceURL.deletingLastPathComponent()
        let sourceStoreName = sourceURL.lastPathComponent
        let destinationStoreName = destinationURL.lastPathComponent

        guard let relatedURLs = try? FileManager.default.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: nil
        ) else {
            copyStoreFileIfPresent(from: sourceURL, to: destinationURL)
            return
        }

        for relatedURL in relatedURLs
        where relatedURL.lastPathComponent.hasPrefix(sourceStoreName) {
            let destinationName = relatedURL.lastPathComponent.replacingPrefix(
                sourceStoreName,
                with: destinationStoreName
            )
            copyStoreFileIfPresent(
                from: relatedURL,
                to: destinationURL.deletingLastPathComponent().appendingPathComponent(destinationName)
            )
        }
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

    private static func makeFallbackContainer() -> ModelContainer {
        let schema = FoodBasketDataSchema.current
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            preconditionFailure("Could not create fallback ModelContainer: \(error)")
        }
    }
}

enum FoodBasketModelContainerError: LocalizedError {
    case containerCreationFailed(Error)
    case managedObjectModelUnavailable
    case cloudKitSchemaStoreLoadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .containerCreationFailed(let error):
            return "Could not open the Food Basket data store. \(error.localizedDescription)"
        case .managedObjectModelUnavailable:
            return "Could not prepare the Food Basket data model for CloudKit."
        case .cloudKitSchemaStoreLoadFailed(let error):
            return "Could not load the Food Basket store for CloudKit schema setup. \(error.localizedDescription)"
        }
    }
}

private extension String {
    func replacingPrefix(_ prefix: String, with replacement: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return replacement + dropFirst(prefix.count)
    }
}
