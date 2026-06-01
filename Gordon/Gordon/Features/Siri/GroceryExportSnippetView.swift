//
//  GroceryExportSnippetView.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import Foundation
import SwiftUI

struct GroceryExportSnippetView: View {
    let listTitle: String?
    let lines: [ShoppingListLine]

    private let maximumVisibleItems = 4

    init(listTitle: String? = nil, lines: [ShoppingListLine]) {
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
            ShoppingListLine(
                ingredientID: UUID(),
                ingredientName: "Basmati rice",
                categoryName: "Pantry",
                unitSymbol: "g",
                photoData: nil,
                quantity: 800
            ),
            ShoppingListLine(
                ingredientID: UUID(),
                ingredientName: "Broccoli",
                categoryName: "Produce",
                unitSymbol: "each",
                photoData: nil,
                quantity: 5
            ),
            ShoppingListLine(
                ingredientID: UUID(),
                ingredientName: "Chicken thigh",
                categoryName: "Meat",
                unitSymbol: "g",
                photoData: nil,
                quantity: 500
            ),
            ShoppingListLine(
                ingredientID: UUID(),
                ingredientName: "Lemon",
                categoryName: "Produce",
                unitSymbol: "each",
                photoData: nil,
                quantity: 1
            ),
            ShoppingListLine(
                ingredientID: UUID(),
                ingredientName: "Tomatoes",
                categoryName: "Produce",
                unitSymbol: "each",
                photoData: nil,
                quantity: 4
            ),
        ]
    )
    .frame(width: 360)
}
