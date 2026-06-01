//
//  String+NormalizedLookupValue.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import Foundation

extension String {
    var normalizedLookupValue: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
