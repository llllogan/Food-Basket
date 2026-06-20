//
//  CalendarRemindersSyncSettingsGroup.swift
//  Food Basket
//
//  Created by Codex on 20/6/2026.
//

import SwiftUI

struct CalendarRemindersSyncSettingsGroup: View {
    @Binding var syncToICal: Bool
    let syncCalendarName: String
    let isUpdatingCalendar: Bool
    let lastRemindersListID: String
    let lastRemindersListName: String
    let lastCalendarID: String
    let lastCalendarName: String
    let onChooseSyncCalendar: () -> Void
    let onClearDefaultRemindersList: () -> Void
    let onClearDefaultCalendar: () -> Void

    var body: some View {
        List {
            Section("Calendar Sync") {
                Toggle("Sync scheduled meals to iCal", isOn: $syncToICal)

                if syncToICal {
                    Button(action: onChooseSyncCalendar) {
                        HStack {
                            Text("Calendar")
                                .foregroundStyle(.primary)
                            Spacer()

                            if isUpdatingCalendar {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(syncCalendarName.isEmpty ? "Choose" : syncCalendarName)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdatingCalendar)
                }
            }

            Section {
                Button(role: .destructive, action: onClearDefaultRemindersList) {
                    defaultExportClearButtonLabel(
                        title: "Clear Default Reminders List",
                        currentValue: lastRemindersListName.isEmpty ? "Not set" : lastRemindersListName
                    )
                }
                .disabled(lastRemindersListID.isEmpty)

                Button(role: .destructive, action: onClearDefaultCalendar) {
                    defaultExportClearButtonLabel(
                        title: "Clear Default Calendar",
                        currentValue: lastCalendarName.isEmpty ? "Not set" : lastCalendarName
                    )
                }
                .disabled(lastCalendarID.isEmpty)
            } header: {
                Text("Export Defaults")
            } footer: {
                Text("Food Basket uses these defaults for quick grocery and calendar exports.")
            }
        }
        .navigationTitle("Calendar and Reminders")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .listStyle(.insetGrouped)
    }

    private func defaultExportClearButtonLabel(
        title: String,
        currentValue: String
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(currentValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
