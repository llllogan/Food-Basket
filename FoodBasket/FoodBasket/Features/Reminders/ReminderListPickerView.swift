//
//  ReminderListPickerView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI

struct ReminderListPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let lists: [ReminderListOption]
    let onSelect: (ReminderListOption) -> Void

    var body: some View {
        List(lists) { list in
            Button {
                dismiss()
                onSelect(list)
            } label: {
                VStack(alignment: .leading) {
                    Text(list.title)
                    Text(list.sourceTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        }
        .listStyle(.plain)
        .navigationTitle("Choose Reminders List")
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

#Preview("Reminders List Picker") {
    NavigationStack {
        ReminderListPickerView(
            lists: [
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
