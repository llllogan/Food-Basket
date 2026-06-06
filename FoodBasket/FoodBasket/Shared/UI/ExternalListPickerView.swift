//
//  ExternalListPickerView.swift
//  Food Basket
//
//  Created by Codex on 6/6/2026.
//

import SwiftUI

protocol ExternalListOption: Identifiable {
    var title: String { get }
    var sourceTitle: String { get }
}

struct ExternalListPickerView<Option: ExternalListOption>: View {
    @Environment(\.dismiss) private var dismiss

    let isCalendar: Bool
    let options: [Option]
    let onSelect: (Option) -> Void

    var body: some View {
        List(options) { option in
            Button {
                dismiss()
                onSelect(option)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isCalendar ? "calendar" : "list.bullet.rectangle.portrait")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .foregroundStyle(.primary)

                        if !option.sourceTitle.isEmpty {
                            Text(option.sourceTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .navigationTitle(isCalendar ? "Choose Calendar" : "Choose List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview("Calendar Picker") {
    NavigationStack {
        ExternalListPickerView(
            isCalendar: true,
            options: [
                CalendarListOption(
                    id: "home",
                    title: "Home",
                    sourceTitle: "iCloud"
                ),
                CalendarListOption(
                    id: "family",
                    title: "Family",
                    sourceTitle: "iCloud"
                ),
            ]
        ) { _ in }
    }
}

#Preview("Reminders List Picker") {
    NavigationStack {
        ExternalListPickerView(
            isCalendar: false,
            options: [
                ReminderListOption(
                    id: "groceries",
                    title: "Groceries",
                    sourceTitle: "iCloud"
                ),
                ReminderListOption(
                    id: "shared",
                    title: "Shared Shopping",
                    sourceTitle: "iCloud"
                ),
            ],
            onSelect: { _ in }
        )
    }
}
