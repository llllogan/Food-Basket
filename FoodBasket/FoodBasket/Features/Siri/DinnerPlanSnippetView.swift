//
//  DinnerPlanSnippetView.swift
//  Food Basket
//
//  Created by Codex on 1/6/2026.
//

import SwiftUI
import UIKit

struct DinnerPlanSnippetView: View {
    let recipePhotoData: [Data?]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )
    private let maximumVisibleMeals = 9

    var body: some View {
        Group {
            if recipePhotoData.isEmpty {
                DinnerPlanSnippetPhotoView(photoData: nil)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(recipePhotoData.prefix(maximumVisibleMeals).enumerated()), id: \.offset) { _, photoData in
                        DinnerPlanSnippetPhotoView(photoData: photoData)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
}

private struct DinnerPlanSnippetPhotoView: View {
    let photoData: Data?

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)

                    Image(systemName: "fork.knife")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview("Dinner Plan Snippet") {
    DinnerPlanSnippetView(
        recipePhotoData: Array(repeating: nil, count: 7)
    )
    .background(Color.orange.opacity(0.25))
    .frame(width: 360)
}
