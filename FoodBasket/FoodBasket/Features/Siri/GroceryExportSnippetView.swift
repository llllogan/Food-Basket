//
//  GroceryExportSnippetView.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import Foundation
import SwiftUI

struct GroceryExportSnippetView: View {
    let listTitle: String?
    let lines: [FoodBasketPlanSnapshotGroceryLine]

    private let maximumVisibleItems = 4

    init(listTitle: String? = nil, lines: [FoodBasketPlanSnapshotGroceryLine]) {
        self.listTitle = listTitle
        self.lines = lines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                lines.isEmpty ? "No Groceries Planned" : "Added \(lines.count) Grocery Items",
                systemImage: lines.isEmpty ? "cart" : "checkmark.circle.fill"
            )
            .font(.headline)

            if let listTitle {
                Text("To: \(listTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if lines.isEmpty {
                Text("Add meals to this week to build your shopping list.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(lines.prefix(maximumVisibleItems))) { line in
                    HStack {
                        Text(line.ingredientName)
                            .lineLimit(1)
                        Spacer()
                        Text(line.formattedAmount)
                            .foregroundStyle(.secondary)
                    }
                }

                if additionalItemCount > 0 {
                    Text("+ \(additionalItemCount) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var additionalItemCount: Int {
        max(0, lines.count - maximumVisibleItems)
    }
}

#Preview("Grocery Export Snippet") {
    GroceryExportSnippetView(
        listTitle: "Groceries",
        lines: [
            FoodBasketPlanSnapshotGroceryLine(
                ingredientID: UUID(),
                ingredientName: "Basmati rice",
                categoryName: "Pantry",
                unitSymbol: "g",
                quantity: 800
            ),
            FoodBasketPlanSnapshotGroceryLine(
                ingredientID: UUID(),
                ingredientName: "Broccoli",
                categoryName: "Produce",
                unitSymbol: "each",
                quantity: 5
            ),
            FoodBasketPlanSnapshotGroceryLine(
                ingredientID: UUID(),
                ingredientName: "Chicken thigh",
                categoryName: "Meat",
                unitSymbol: "g",
                quantity: 500
            ),
            FoodBasketPlanSnapshotGroceryLine(
                ingredientID: UUID(),
                ingredientName: "Lemon",
                categoryName: "Produce",
                unitSymbol: "each",
                quantity: 1
            ),
            FoodBasketPlanSnapshotGroceryLine(
                ingredientID: UUID(),
                ingredientName: "Tomatoes",
                categoryName: "Produce",
                unitSymbol: "each",
                quantity: 4
            ),
        ]
    )
    .frame(width: 360)
}
