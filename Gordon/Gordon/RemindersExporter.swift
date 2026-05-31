//
//  RemindersExporter.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import EventKit
import Foundation

@MainActor
final class RemindersExporter {
    private static let automaticallyAddedTag = "#added_automatically"

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

    func export(_ lines: [ShoppingListLine], to list: ReminderListOption) async throws {
        try await requestAccessIfNeeded()

        guard let calendar = eventStore.calendar(withIdentifier: list.id) else {
            throw RemindersExportError.listUnavailable
        }

        for line in lines {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
            reminder.title = "\(line.ingredientName) - \(line.formattedAmount)"
            reminder.notes = Self.automaticallyAddedTag
            try eventStore.save(reminder, commit: false)
        }

        try eventStore.commit()
    }

    func clearAutomaticallyAddedReminders(from list: ReminderListOption) async throws -> Int {
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
            $0.notes == Self.automaticallyAddedTag
        }

        for reminder in automaticallyAddedReminders {
            try eventStore.remove(reminder, commit: false)
        }

        if !automaticallyAddedReminders.isEmpty {
            try eventStore.commit()
        }

        return automaticallyAddedReminders.count
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

struct ReminderListOption: Identifiable {
    let id: String
    let title: String
    let sourceTitle: String
}

enum RemindersExportError: LocalizedError, Equatable {
    case accessDenied
    case listUnavailable
    case noWritableLists

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Allow Reminders access in Settings to update your shopping list."
        case .listUnavailable:
            "The selected Reminders list is no longer available."
        case .noWritableLists:
            "No writable Reminders lists are available."
        }
    }
}
