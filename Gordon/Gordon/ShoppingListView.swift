//
//  ShoppingListView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Query(sort: \WeekPlan.weekStarting) private var plans: [WeekPlan]
    @State private var remindersExporter = RemindersExporter()
    @State private var reminderLists: [ReminderListOption] = []
    @State private var showingReminderListPicker = false
    @State private var isPreparingReminderExport = false
    @State private var exportAlert: ReminderExportAlert?

    private let weekStarting = Calendar.current.startOfWeek(containing: Date())

    private var currentPlan: WeekPlan? {
        plans.first {
            Calendar.current.isDate($0.weekStarting, inSameDayAs: weekStarting)
        }
    }

    private var lines: [ShoppingListLine] {
        ShoppingListLine.makeLines(for: currentPlan)
    }

    private var categories: [String] {
        Set(lines.map(\.categoryName)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if lines.isEmpty {
                    Text("Add meals to this week to build your shopping list.")
                        .foregroundStyle(.secondary)
                }

                ForEach(categories, id: \.self) { category in
                    Section(category) {
                        ForEach(lines.filter { $0.categoryName == category }) { line in
                            HStack {
                                Text(line.ingredientName)
                                Spacer()
                                Text(line.formattedAmount)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prepareReminderExport()
                    } label: {
                        if isPreparingReminderExport {
                            ProgressView()
                        } else {
                            Label("Export to Reminders", systemImage: "checklist")
                        }
                    }
                    .disabled(lines.isEmpty || isPreparingReminderExport)
                }
            }
            .sheet(isPresented: $showingReminderListPicker) {
                NavigationStack {
                    ReminderListPickerView(lists: reminderLists) { list in
                        exportReminders(to: list)
                    }
                }
            }
            .alert(item: $exportAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func prepareReminderExport() {
        isPreparingReminderExport = true

        Task { @MainActor in
            defer {
                isPreparingReminderExport = false
            }

            do {
                reminderLists = try await remindersExporter.availableLists()

                guard !reminderLists.isEmpty else {
                    throw RemindersExportError.noWritableLists
                }

                showingReminderListPicker = true
            } catch {
                showExportError(error)
            }
        }
    }

    private func exportReminders(to list: ReminderListOption) {
        do {
            try remindersExporter.export(lines, to: list)
            exportAlert = ReminderExportAlert(
                title: "Shopping List Exported",
                message: "\(lines.count) items were added to \(list.title)."
            )
        } catch {
            showExportError(error)
        }
    }

    private func showExportError(_ error: Error) {
        exportAlert = ReminderExportAlert(
            title: "Unable to Export",
            message: error.localizedDescription
        )
    }
}

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

#Preview("Shopping List") {
    let previewData = PreviewData()

    ShoppingListView()
        .modelContainer(previewData.container)
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
