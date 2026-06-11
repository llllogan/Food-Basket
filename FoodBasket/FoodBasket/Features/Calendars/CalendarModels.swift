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

extension CalendarListOption: ExternalListOption {}

enum CalendarListDefaults {
    static let idKey = "lastCalendarID"
    static let nameKey = "lastCalendarName"
    static let sourceTitleKey = "lastCalendarSourceTitle"

    static var rememberedCalendar: CalendarListOption? {
        let id = FoodBasketSharedContainer.string(forKey: idKey) ?? ""
        let name = FoodBasketSharedContainer.string(forKey: nameKey) ?? ""
        let sourceTitle = FoodBasketSharedContainer.string(forKey: sourceTitleKey) ?? ""

        guard !id.isEmpty, !name.isEmpty else { return nil }

        return CalendarListOption(
            id: id,
            title: name,
            sourceTitle: sourceTitle
        )
    }
}

enum CalendarSyncDefaults {
    static let isEnabledKey = "syncToICal"
    static let calendarIDKey = "syncCalendarID"
    static let calendarNameKey = "syncCalendarName"
    static let calendarSourceTitleKey = "syncCalendarSourceTitle"

    static var selectedCalendar: CalendarListOption? {
        let id = FoodBasketSharedContainer.string(forKey: calendarIDKey) ?? ""
        let name = FoodBasketSharedContainer.string(forKey: calendarNameKey) ?? ""
        let sourceTitle = FoodBasketSharedContainer.string(forKey: calendarSourceTitleKey) ?? ""

        guard !id.isEmpty, !name.isEmpty else { return nil }

        return CalendarListOption(
            id: id,
            title: name,
            sourceTitle: sourceTitle
        )
    }

    static func remember(_ calendar: CalendarListOption) {
        let defaults = FoodBasketSharedContainer.userDefaults
        defaults.set(calendar.id, forKey: calendarIDKey)
        defaults.set(calendar.title, forKey: calendarNameKey)
        defaults.set(calendar.sourceTitle, forKey: calendarSourceTitleKey)
    }

    static func forgetSelectedCalendar() {
        let defaults = FoodBasketSharedContainer.userDefaults
        defaults.set("", forKey: calendarIDKey)
        defaults.set("", forKey: calendarNameKey)
        defaults.set("", forKey: calendarSourceTitleKey)
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
