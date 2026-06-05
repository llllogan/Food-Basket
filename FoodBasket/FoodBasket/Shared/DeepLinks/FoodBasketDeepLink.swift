//
//  FoodBasketDeepLink.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation

enum FoodBasketDeepLink {
    case recipe(UUID)

    static let scheme = "foodbasket"

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }

        switch url.host {
        case "recipe":
            guard let idString = url.pathComponents.dropFirst().first,
                  let recipeID = UUID(uuidString: idString) else {
                return nil
            }

            self = .recipe(recipeID)
        default:
            return nil
        }
    }

    static func recipeURL(for recipeID: UUID) -> URL {
        URL(string: "\(scheme)://recipe/\(recipeID.uuidString)")!
    }
}
