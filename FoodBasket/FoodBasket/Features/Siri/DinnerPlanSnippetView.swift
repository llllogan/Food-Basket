//
//  DinnerPlanSnippetView.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import SwiftUI

struct DinnerPlanSnippetView: View {
    private let maximumVisibleMeals = 9
    let mealNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                mealNames.isEmpty ? "No Dinners Planned" : "This Week's Dinners",
                systemImage: "fork.knife"
            )
            .font(.headline)

            if mealNames.isEmpty {
                Text("Add meals in Food Basket to see them here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(mealNames.prefix(maximumVisibleMeals).enumerated()), id: \.offset) { _, mealName in
                    Text(mealName)
                        .lineLimit(1)
                }

                if additionalMealCount > 0 {
                    Text("+ \(additionalMealCount) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var additionalMealCount: Int {
        max(0, mealNames.count - maximumVisibleMeals)
    }
}

#Preview("Dinner Plan Snippet") {
    DinnerPlanSnippetView(
        mealNames: [
            "Lemon Chicken with Rice",
            "Broccoli Rice Bowl",
            "Tomato Pasta",
        ]
    )
    .background(Color.orange.opacity(0.25))
    .frame(width: 360)
}
