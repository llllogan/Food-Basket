//
//  RemindersExporter.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import EventKit
import Foundation

@MainActor
final class RemindersExporter {
    private static let automaticallyAddedTag = "#added_automatically"
    private static let sourcePrefix = "source="

    private let eventStore = EKEventStore()

    func availableLists() async throws -> [ReminderListOption] {
        try await requestAccessIfNeeded()

        return eventStore.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .map {
                ReminderListOption(
                    id: $0.calendarIdentifier,
                    title: $0.title,
                    sourceTitle: $0.source.title
                )
            }
            .sorted {
                if $0.sourceTitle == $1.sourceTitle {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.sourceTitle.localizedCaseInsensitiveCompare($1.sourceTitle) == .orderedAscending
            }
    }

    func export(
        _ lines: [ShoppingListLine],
        to list: ReminderListOption,
        sourceIdentifier: String? = nil
    ) async throws {
        try await requestAccessIfNeeded()

        guard let calendar = eventStore.calendar(withIdentifier: list.id) else {
            throw RemindersExportError.listUnavailable
        }

        try export(lines, to: calendar, sourceIdentifier: sourceIdentifier)
    }

    private func export(
        _ lines: [ShoppingListLine],
        to calendar: EKCalendar,
        sourceIdentifier: String?
    ) throws {
        for line in lines {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
            reminder.title = "\(line.ingredientName) - \(line.formattedAmount)"
            reminder.notes = Self.notes(for: sourceIdentifier)
            try eventStore.save(reminder, commit: false)
        }

        try eventStore.commit()
    }

    func clearAutomaticallyAddedReminders(
        from list: ReminderListOption,
        sourceIdentifier: String? = nil
    ) async throws -> Int {
        try await requestAccessIfNeeded()

        guard let calendar = eventStore.calendar(withIdentifier: list.id) else {
            throw RemindersExportError.listUnavailable
        }

        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = await withCheckedContinuation {
            (continuation: CheckedContinuation<[EKReminder], Never>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        let automaticallyAddedReminders = reminders.filter {
            Self.isAutomaticallyAdded($0, sourceIdentifier: sourceIdentifier)
        }

        for reminder in automaticallyAddedReminders {
            try eventStore.remove(reminder, commit: false)
        }

        if !automaticallyAddedReminders.isEmpty {
            try eventStore.commit()
        }

        return automaticallyAddedReminders.count
    }

    private static func notes(for sourceIdentifier: String?) -> String {
        let trimmedSourceIdentifier = sourceIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmedSourceIdentifier.isEmpty else {
            return automaticallyAddedTag
        }

        return [
            automaticallyAddedTag,
            "\(sourcePrefix)\(trimmedSourceIdentifier)",
        ].joined(separator: "\n")
    }

    private static func isAutomaticallyAdded(
        _ reminder: EKReminder,
        sourceIdentifier: String?
    ) -> Bool {
        let noteLines = Set((reminder.notes ?? "").components(separatedBy: .newlines))
        guard noteLines.contains(automaticallyAddedTag) else {
            return false
        }

        guard let sourceIdentifier else {
            return true
        }

        return noteLines.contains("\(sourcePrefix)\(sourceIdentifier)")
    }

    private func requestAccessIfNeeded() async throws {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return
        case .notDetermined:
            try await requestFullAccess()
        default:
            throw RemindersExportError.accessDenied
        }
    }

    private func requestFullAccess() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: RemindersExportError.accessDenied)
                }
            }
        }
    }
}
