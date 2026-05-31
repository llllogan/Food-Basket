//
//  ShoppingListSupport.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import Foundation
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

struct ReminderExportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension ShoppingListLine {
    var formattedAmount: String {
        guard !unitSymbol.isEmpty else { return formattedQuantity }
        return "\(formattedQuantity) \(unitSymbol)"
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
