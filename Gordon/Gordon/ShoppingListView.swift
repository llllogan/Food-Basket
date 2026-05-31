//
//  ShoppingListView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]

    private let weekStarting = Calendar.current.startOfWeek(containing: Date())

    private var currentPlan: WeekPlan? {
        plans.first {
            Calendar.current.isDate($0.weekStarting, inSameDayAs: weekStarting)
        }
    }

    private var lines: [ShoppingListLine] {
        ShoppingListLine.makeLines(for: currentPlan)
    }

    private var categories: [String] {
        Set(lines.map(\.categoryName)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if lines.isEmpty {
                    Text("Add meals to this week to build your shopping list.")
                        .foregroundStyle(.secondary)
                }

                ForEach(categories, id: \.self) { category in
                    Section(category) {
                        ForEach(lines.filter { $0.categoryName == category }) { line in
                            HStack {
                                Text(line.ingredientName)
                                Spacer()
                                Text(line.formattedAmount)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping List")
        }
    }
}

private extension ShoppingListLine {
    var formattedAmount: String {
        guard !unitSymbol.isEmpty else { return formattedQuantity }
        return "\(formattedQuantity) \(unitSymbol)"
    }
}
