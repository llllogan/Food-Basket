//
//  CalendarListPickerView.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import SwiftUI

struct CalendarListPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let calendars: [CalendarListOption]
    let onSelect: (CalendarListOption) -> Void

    var body: some View {
        List(calendars) { calendar in
            Button {
                onSelect(calendar)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(calendar.title)
                        .foregroundStyle(.primary)
                    if !calendar.sourceTitle.isEmpty {
                        Text(calendar.sourceTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Choose Calendar")
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
        CalendarListPickerView(
            calendars: [
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
