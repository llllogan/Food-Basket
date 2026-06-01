//
//  Calendar+StartOfWeek.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import Foundation

extension Calendar {
    func startOfWeek(containing date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
