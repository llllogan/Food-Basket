//
//  CalendarModels.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation

struct CalendarListOption: Identifiable {
    let id: String
    let title: String
    let sourceTitle: String
}

enum CalendarListDefaults {
    static let idKey = "lastCalendarID"
    static let nameKey = "lastCalendarName"

    static var rememberedCalendar: CalendarListOption? {
        let defaults = UserDefaults.standard
        let id = defaults.string(forKey: idKey) ?? ""
        let name = defaults.string(forKey: nameKey) ?? ""

        guard !id.isEmpty, !name.isEmpty else { return nil }

        return CalendarListOption(
            id: id,
            title: name,
            sourceTitle: ""
        )
    }
}

enum CalendarSyncDefaults {
    static let isEnabledKey = "syncToICal"
    static let calendarIDKey = "syncCalendarID"
    static let calendarNameKey = "syncCalendarName"

    static var selectedCalendar: CalendarListOption? {
        let defaults = UserDefaults.standard
        let id = defaults.string(forKey: calendarIDKey) ?? ""
        let name = defaults.string(forKey: calendarNameKey) ?? ""

        guard !id.isEmpty, !name.isEmpty else { return nil }

        return CalendarListOption(
            id: id,
            title: name,
            sourceTitle: ""
        )
    }

    static func forgetSelectedCalendar() {
        let defaults = UserDefaults.standard
        defaults.set("", forKey: calendarIDKey)
        defaults.set("", forKey: calendarNameKey)
    }
}

enum CalendarExportError: LocalizedError, Equatable {
    case accessDenied
    case calendarUnavailable
    case noWritableCalendars

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Allow Calendar access in Settings to add and remove meal plan events."
        case .calendarUnavailable:
            "The selected Calendar is no longer available."
        case .noWritableCalendars:
            "No writable Calendars are available."
        }
    }
}
