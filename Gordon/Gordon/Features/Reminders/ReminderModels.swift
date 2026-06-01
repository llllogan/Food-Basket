//
//  ReminderModels.swift
//  Gordon
//
//  Created by Codex on 1/6/2026.
//

import Foundation

struct ReminderListOption: Identifiable {
    let id: String
    let title: String
    let sourceTitle: String
}

struct ReminderExportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum ReminderListDefaults {
    static let idKey = "lastRemindersListID"
    static let nameKey = "lastRemindersListName"

    static var rememberedList: ReminderListOption? {
        let defaults = UserDefaults.standard
        let id = defaults.string(forKey: idKey) ?? ""
        let name = defaults.string(forKey: nameKey) ?? ""

        guard !id.isEmpty, !name.isEmpty else { return nil }

        return ReminderListOption(
            id: id,
            title: name,
            sourceTitle: ""
        )
    }
}

enum RemindersExportError: LocalizedError, Equatable {
    case accessDenied
    case listUnavailable
    case noRememberedList
    case noWritableLists

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Allow Reminders access in Settings to update your shopping list."
        case .listUnavailable:
            "The selected Reminders list is no longer available."
        case .noRememberedList:
            "Choose a Reminders list in Gordon before asking Siri to add groceries."
        case .noWritableLists:
            "No writable Reminders lists are available."
        }
    }
}
