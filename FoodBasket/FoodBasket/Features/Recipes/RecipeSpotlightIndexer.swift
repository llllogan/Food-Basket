//
//  RecipeSpotlightIndexer.swift
//  Food Basket
//
//  Created by Codex on 9/6/2026.
//

import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

struct RecipeSpotlightSnapshot: Hashable {
    let id: UUID
    let name: String
    let mealTypeName: String?
    let method: String
    let cookingTimeMinutes: Int
    let serves: Int
    let rating: Int
    let ingredientNames: [String]
    let photoData: Data?
}

enum RecipeSpotlightIndexer {
    private static let domainIdentifier = "recipes"
    private static var pendingTask: Task<Void, Never>?

    @MainActor
    static func scheduleReindexing(recipes: [Recipe]) {
        guard !isRunningForPreviews else { return }

        let snapshots = recipes.map(RecipeSpotlightSnapshot.init(recipe:))
        pendingTask?.cancel()
        pendingTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await reindex(snapshots: snapshots)
        }
    }

    static func recipeID(from searchableItemUniqueIdentifier: String) -> UUID? {
        guard searchableItemUniqueIdentifier.hasPrefix(uniqueIdentifierPrefix) else { return nil }

        let idString = String(searchableItemUniqueIdentifier.dropFirst(uniqueIdentifierPrefix.count))
        return UUID(uuidString: idString)
    }

    private static var uniqueIdentifierPrefix: String {
        "recipe:"
    }

    private static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private static func reindex(snapshots: [RecipeSpotlightSnapshot]) async {
        await deleteExistingRecipeItems()

        let items = snapshots.map(searchableItem(for:))
        guard !items.isEmpty else { return }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
        } catch {
            // Spotlight indexing is opportunistic; failed attempts are retried when the app refreshes the index again.
        }
    }

    private static func deleteExistingRecipeItems() async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
        } catch {
            // A stale result is preferable to interrupting normal app startup or recipe editing.
        }
    }

    private static func searchableItem(for recipe: RecipeSpotlightSnapshot) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = recipe.name
        attributeSet.displayName = recipe.name
        attributeSet.contentDescription = recipe.subtitle
        attributeSet.textContent = recipe.searchableText
        attributeSet.keywords = recipe.keywords
        attributeSet.thumbnailData = recipe.photoData
        attributeSet.contentURL = FoodBasketDeepLink.recipeURL(for: recipe.id)
        attributeSet.metadataModificationDate = Date()

        let item = CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier(for: recipe.id),
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        item.expirationDate = Date.distantFuture
        return item
    }

    private static func uniqueIdentifier(for recipeID: UUID) -> String {
        "\(uniqueIdentifierPrefix)\(recipeID.uuidString)"
    }
}

extension RecipeSpotlightSnapshot {
    @MainActor
    init(recipe: Recipe) {
        id = recipe.id
        name = recipe.name
        mealTypeName = recipe.mealType?.name
        method = recipe.method
        cookingTimeMinutes = recipe.cookingTimeMinutes
        serves = recipe.serves
        rating = recipe.rating
        ingredientNames = (recipe.ingredientLines ?? [])
            .compactMap { $0.ingredient?.name }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        photoData = recipe.photoData
    }

    var subtitle: String {
        var parts: [String] = []

        if let mealTypeName, !mealTypeName.isEmpty {
            parts.append(mealTypeName)
        }

        if cookingTimeMinutes > 0 {
            parts.append("\(cookingTimeMinutes) min")
        }

        if serves > 0 {
            parts.append("Serves \(serves)")
        }

        if !ingredientNames.isEmpty {
            parts.append("\(ingredientNames.count) ingredients")
        }

        return parts.joined(separator: " | ")
    }

    var keywords: [String] {
        ([name, mealTypeName].compactMap { $0 } + ingredientNames)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var searchableText: String {
        (keywords + [method, subtitle])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
