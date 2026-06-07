//
//  CalendarEventExporter.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import EventKit
import Foundation

@MainActor
final class CalendarEventExporter {
    private static let automaticallyAddedTag = "#foodbasket_calendar_event"

    private let eventStore = EKEventStore()

    func availableCalendars() async throws -> [CalendarListOption] {
        try await requestAccessIfNeeded()

        return eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map(Self.option(for:))
            .sorted {
                if $0.sourceTitle == $1.sourceTitle {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.sourceTitle.localizedCaseInsensitiveCompare($1.sourceTitle) == .orderedAscending
            }
    }

    func resolvedWritableCalendar(matching calendarOption: CalendarListOption) async throws -> CalendarListOption {
        try await requestAccessIfNeeded()

        guard let calendar = writableCalendar(matching: calendarOption) else {
            throw CalendarExportError.calendarUnavailable
        }

        return Self.option(for: calendar)
    }

    func export(
        _ portions: [PlannedMealPortion],
        weekStarting: Date,
        dayCount: Int,
        to calendarOption: CalendarListOption
    ) async throws -> Int {
        try await requestAccessIfNeeded()

        guard let calendar = writableCalendar(matching: calendarOption) else {
            throw CalendarExportError.calendarUnavailable
        }

        return try export(
            portions,
            weekStarting: weekStarting,
            dayCount: dayCount,
            to: calendar
        )
    }

    func clearAutomaticallyAddedEvents(
        from calendarOption: CalendarListOption,
        weekStarting: Date
    ) async throws -> Int {
        try await requestAccessIfNeeded()

        guard let calendar = writableCalendar(matching: calendarOption) else {
            throw CalendarExportError.calendarUnavailable
        }

        return try clearAutomaticallyAddedEvents(
            from: calendar,
            weekStarting: weekStarting
        )
    }

    func replaceAutomaticallyAddedEvents(
        _ portions: [PlannedMealPortion],
        weekStarting: Date,
        dayCount: Int,
        to calendarOption: CalendarListOption
    ) async throws -> Int {
        try await requestAccessIfNeeded()

        guard let calendar = writableCalendar(matching: calendarOption) else {
            throw CalendarExportError.calendarUnavailable
        }

        _ = try clearAutomaticallyAddedEvents(
            from: calendar,
            weekStarting: weekStarting
        )
        return try export(
            portions,
            weekStarting: weekStarting,
            dayCount: dayCount,
            to: calendar
        )
    }

    private func writableCalendar(matching calendarOption: CalendarListOption) -> EKCalendar? {
        if let calendar = eventStore.calendar(withIdentifier: calendarOption.id),
           calendar.allowsContentModifications {
            return calendar
        }

        let writableCalendars = eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)

        if !calendarOption.sourceTitle.isEmpty,
           let calendar = writableCalendars.first(where: {
               $0.title == calendarOption.title &&
               $0.source.title == calendarOption.sourceTitle
           }) {
            return calendar
        }

        let matchingTitleCalendars = writableCalendars.filter {
            $0.title == calendarOption.title
        }

        return matchingTitleCalendars.count == 1 ? matchingTitleCalendars[0] : nil
    }

    private static func option(for calendar: EKCalendar) -> CalendarListOption {
        CalendarListOption(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title
        )
    }

    private func clearAutomaticallyAddedEvents(
        from calendar: EKCalendar,
        weekStarting: Date
    ) throws -> Int {
        let identifierCalendar = Self.identifierCalendar(for: .current)
        let syncIdentifiers = Self.syncIdentifiers(
            forWeekStarting: weekStarting,
            calendar: identifierCalendar
        )
        var removedCount = 0

        for interval in Self.eventSearchIntervals() {
            let predicate = eventStore.predicateForEvents(
                withStart: interval.start,
                end: interval.end,
                calendars: [calendar]
            )
            let matchingEvents = eventStore.events(matching: predicate).filter {
                guard let notes = $0.notes else { return false }

                return Self.notes(notes, containsAny: syncIdentifiers)
            }

            for event in matchingEvents {
                try eventStore.remove(event, span: .thisEvent, commit: false)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            try eventStore.commit()
        }

        return removedCount
    }

    private func export(
        _ portions: [PlannedMealPortion],
        weekStarting: Date,
        dayCount: Int,
        to calendar: EKCalendar
    ) throws -> Int {
        let eventTimeZone = TimeZone.current
        let eventCalendar = Self.calendar(for: eventTimeZone)
        let identifierCalendar = Self.identifierCalendar(for: eventTimeZone)
        let syncIdentifier = Self.syncIdentifier(
            forWeekStarting: weekStarting,
            calendar: identifierCalendar
        )
        let days = Self.eventDays(
            from: portions,
            weekStarting: weekStarting,
            dayCount: dayCount,
            calendar: eventCalendar
        )
        guard !days.isEmpty else { return 0 }

        for day in days {
            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            event.title = day.title
            event.timeZone = eventTimeZone
            event.isAllDay = true
            event.startDate = day.date
            event.endDate = day.endDate(in: eventCalendar)
            event.notes = Self.notes(
                for: day,
                syncIdentifier: syncIdentifier
            )

            if let linkedRecipe = day.primaryRecipeLine {
                event.url = FoodBasketDeepLink.recipeURL(for: linkedRecipe.recipeID)
            }

            try eventStore.save(event, span: .thisEvent, commit: false)
        }

        try eventStore.commit()
        return days.count
    }

    private func requestAccessIfNeeded() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return
        case .notDetermined:
            try await requestFullAccess()
        default:
            throw CalendarExportError.accessDenied
        }
    }

    private func requestFullAccess() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: CalendarExportError.accessDenied)
                }
            }
        }
    }

    private static func eventDays(
        from portions: [PlannedMealPortion],
        weekStarting: Date,
        dayCount: Int,
        calendar: Calendar
    ) -> [CalendarEventDay] {
        let portionsByDay = Dictionary(
            grouping: portions.filter {
                (0..<dayCount).contains($0.dayOffset) && $0.plannedMeal?.recipe != nil
            },
            by: \.dayOffset
        )

        return portionsByDay.keys.sorted().compactMap { dayOffset in
            guard let dayPortions = portionsByDay[dayOffset] else { return nil }

            let recipeLines = recipeLines(from: dayPortions)
            guard !recipeLines.isEmpty else { return nil }

            let date = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: weekStarting
            ) ?? weekStarting

            return CalendarEventDay(
                date: calendar.startOfDay(for: date),
                recipeLines: recipeLines
            )
        }
    }

    private static func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        return calendar
    }

    private static func identifierCalendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func recipeLines(from portions: [PlannedMealPortion]) -> [CalendarEventRecipeLine] {
        let sortedPortions = portions.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }

            return (lhs.plannedMeal?.sortOrder ?? 0) < (rhs.plannedMeal?.sortOrder ?? 0)
        }
        var recipeLines: [CalendarEventRecipeLine] = []

        for (index, portion) in sortedPortions.enumerated() {
            guard let recipe = portion.plannedMeal?.recipe else { continue }

            if let existingIndex = recipeLines.firstIndex(where: { $0.recipeID == recipe.id }) {
                recipeLines[existingIndex].count += 1
            } else {
                recipeLines.append(
                    CalendarEventRecipeLine(
                        recipeID: recipe.id,
                        recipeName: recipe.name,
                        count: 1,
                        firstSortIndex: index
                    )
                )
            }
        }

        return recipeLines.sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }

            return lhs.firstSortIndex < rhs.firstSortIndex
        }
    }

    private static func notes(
        for day: CalendarEventDay,
        syncIdentifier: String
    ) -> String {
        let recipeIDs = day.recipeLines
            .map(\.recipeID.uuidString)
            .joined(separator: ",")

        return """
        \(automaticallyAddedTag)
        \(syncIdentifier)
        recipes=\(recipeIDs)
        """
    }

    private static func syncIdentifiers(
        forWeekStarting weekStarting: Date,
        calendar: Calendar
    ) -> [String] {
        let weekStarting = calendar.startOfDay(for: weekStarting)
        var identifiers = [
            syncIdentifier(
                forWeekStarting: weekStarting,
                calendar: calendar
            ),
        ]

        if calendar.component(.weekday, from: weekStarting) == 2 {
            identifiers.append(legacySyncIdentifier(for: weekStarting))
        }

        return identifiers
    }

    private static func syncIdentifier(
        forWeekStarting weekStarting: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: calendar.startOfDay(for: weekStarting)
        )

        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return "foodbasket-calendar-sync:\(Int(weekStarting.timeIntervalSince1970))"
        }

        return "foodbasket-calendar-sync:\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }

    private static func notes(
        _ notes: String,
        containsAny syncIdentifiers: [String]
    ) -> Bool {
        syncIdentifiers.contains { notes.contains($0) }
    }

    private static func legacySyncIdentifier(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current

        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date
        )
        let year = components.yearForWeekOfYear ?? calendar.component(.year, from: date)
        let week = components.weekOfYear ?? 1

        return "foodbasket-calendar-sync:\(year)-W\(String(format: "%02d", week))"
    }

    private static func eventSearchIntervals() -> [(start: Date, end: Date)] {
        let calendar = Calendar(identifier: .gregorian)
        let startYear = 2001
        let endYear = 2100
        var intervals: [(start: Date, end: Date)] = []
        var year = startYear

        while year < endYear {
            guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let end = calendar.date(from: DateComponents(year: min(year + 3, endYear), month: 1, day: 1)) else {
                break
            }

            intervals.append((start, end))
            year += 3
        }

        return intervals
    }
}

private struct CalendarEventDay {
    let date: Date
    let recipeLines: [CalendarEventRecipeLine]

    func endDate(in calendar: Calendar) -> Date {
        let nextDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: date
        ) ?? date.addingTimeInterval(24 * 60 * 60)

        return nextDay.addingTimeInterval(-1)
    }

    var primaryRecipeLine: CalendarEventRecipeLine? {
        recipeLines.first
    }

    var title: String {
        recipeLines
            .map(\.title)
            .joined(separator: ", ")
    }
}

private struct CalendarEventRecipeLine {
    let recipeID: UUID
    let recipeName: String
    var count: Int
    let firstSortIndex: Int

    var title: String {
        guard count > 1 else { return recipeName }

        return "\(recipeName) x\(count)"
    }
}
