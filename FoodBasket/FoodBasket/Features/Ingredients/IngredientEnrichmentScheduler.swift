//
//  IngredientEnrichmentScheduler.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation
import SwiftData

@MainActor
enum IngredientEnrichmentScheduler {
    private static var pendingTask: Task<Void, Never>?

    static func schedulePendingIngredientEnrichment(
        in modelContext: ModelContext,
        delay: Duration = .seconds(3)
    ) {
        guard pendingTask == nil else { return }

        pendingTask = Task { @MainActor in
            defer { pendingTask = nil }

            do {
                try await Task.sleep(for: delay)
                try Task.checkCancellation()
            } catch {
                return
            }

            await IngredientEnrichmentRunner.enrichPendingIngredients(in: modelContext)
        }
    }

    static func cancelPendingIngredientEnrichment() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
