//
//  WeekPlanSettingsView.swift
//  Food Basket
//
//  Created by Codex on 6/6/2026.
//

import SwiftData
import SwiftUI

struct WeekPlanSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealType.name) private var mealTypes: [MealType]

    @State private var calendarExporter = CalendarEventExporter()
    @State private var syncCalendarLists: [CalendarListOption] = []
    @State private var showingSyncCalendarPicker = false
    @State private var isUpdatingCalendar = false
    @State private var exportAlert: ReminderExportAlert?

    @AppStorage(CalendarListDefaults.idKey) private var lastCalendarID = ""
    @AppStorage(CalendarListDefaults.nameKey) private var lastCalendarName = ""
    @AppStorage(CalendarSyncDefaults.isEnabledKey) private var syncToICal = false
    @AppStorage(CalendarSyncDefaults.calendarIDKey) private var syncCalendarID = ""
    @AppStorage(CalendarSyncDefaults.calendarNameKey) private var syncCalendarName = ""
    @AppStorage(WeekPlanAutomationDefaults.removeMealsAtNewWeekKey) private var removeMealsAtNewWeek = false
    @AppStorage(WeekPlanAutomationDefaults.weekStartDayKey) private var weekStartDay = WeekStartDay.monday.rawValue
    @AppStorage(WeekPlanCalendarFilterDefaults.excludedMealTypeIDsKey) private var excludedCalendarMealTypeIDsRaw = ""
    @AppStorage(WeekPlanCalendarFilterDefaults.excludeMealsWithoutMealTypeKey) private var excludeCalendarMealsWithoutMealType = false
    @AppStorage(ReminderListDefaults.idKey) private var lastRemindersListID = ""
    @AppStorage(ReminderListDefaults.nameKey) private var lastRemindersListName = ""

    private var excludedCalendarMealTypeIDs: Set<UUID> {
        WeekPlanCalendarFilterDefaults.mealTypeIDs(from: excludedCalendarMealTypeIDsRaw)
    }

    private var selectedSyncCalendar: CalendarListOption? {
        guard !syncCalendarID.isEmpty, !syncCalendarName.isEmpty else {
            return nil
        }

        return CalendarListOption(
            id: syncCalendarID,
            title: syncCalendarName,
            sourceTitle: ""
        )
    }

    private var automaticCalendarSyncKey: String {
        [
            syncToICal ? "sync-on" : "sync-off",
            syncCalendarID,
            removeMealsAtNewWeek ? "cleanup-on" : "cleanup-off",
            "\(weekStartDay)",
        ].joined(separator: "#")
    }

    var body: some View {
        NavigationStack {
            List {
                settingsRows
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingSyncCalendarPicker) {
                NavigationStack {
                    ExternalListPickerView(
                        isCalendar: true,
                        options: syncCalendarLists
                    ) { calendar in
                        rememberSyncCalendar(calendar)
                        Task {
                            await performCalendarAutomation()
                        }
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
            .task(id: automaticCalendarSyncKey) {
                await performCalendarAutomation()
            }
        }
    }

    @ViewBuilder
    private var settingsRows: some View {
        iCalSyncSettingsSection
        calendarViewSettingsSection
        weeklyCleanupSettingsSection
        exportDefaultsSettingsSection
    }

    @ViewBuilder
    private var iCalSyncSettingsSection: some View {
        Section("Calendar Sync") {
            Toggle("Sync scheduled meals to iCal", isOn: $syncToICal)

            if syncToICal {
                Button {
                    prepareSyncCalendarSelection()
                } label: {
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
    }

    @ViewBuilder
    private var calendarViewSettingsSection: some View {
        Section {
            if mealTypes.isEmpty {
                Text("Add meal types to recipes to filter the calendar view.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mealTypes) { mealType in
                    Toggle(mealType.name, isOn: calendarMealTypeBinding(for: mealType))
                }
            }

            Toggle("No meal type", isOn: calendarMealsWithoutMealTypeBinding)
        } header: {
            Text("Calendar View")
        } footer: {
            Text("Only selected meal types appear in the This Week calendar view.")
        }
    }

    @ViewBuilder
    private var weeklyCleanupSettingsSection: some View {
        Section("Weekly Cleanup") {
            Toggle("Remove scheduled meals at the start of a new week", isOn: $removeMealsAtNewWeek)

            if removeMealsAtNewWeek {
                Picker("Week starts", selection: $weekStartDay) {
                    ForEach(WeekStartDay.allCases) { day in
                        Text(day.title).tag(day.rawValue)
                    }
                }
            }
        }
    }

    private var exportDefaultsSettingsSection: some View {
        Section {
            Button(role: .destructive) {
                clearDefaultRemindersList()
            } label: {
                defaultExportClearButtonLabel(
                    title: "Clear Default Reminders List",
                    currentValue: lastRemindersListName.isEmpty ? "Not set" : lastRemindersListName
                )
            }
            .disabled(lastRemindersListID.isEmpty)

            Button(role: .destructive) {
                clearDefaultCalendar()
            } label: {
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

    private func prepareSyncCalendarSelection() {
        isUpdatingCalendar = true

        Task { @MainActor in
            defer {
                isUpdatingCalendar = false
            }

            do {
                syncCalendarLists = try await calendarExporter.availableCalendars()

                guard !syncCalendarLists.isEmpty else {
                    throw CalendarExportError.noWritableCalendars
                }

                showingSyncCalendarPicker = true
            } catch {
                showCalendarError(error)
            }
        }
    }

    private func rememberSyncCalendar(_ calendar: CalendarListOption) {
        syncCalendarID = calendar.id
        syncCalendarName = calendar.title
    }

    private func clearDefaultCalendar() {
        lastCalendarID = ""
        lastCalendarName = ""
    }

    private func clearDefaultRemindersList() {
        lastRemindersListID = ""
        lastRemindersListName = ""
    }

    private func forgetSyncCalendar(ifMatching calendar: CalendarListOption) {
        guard calendar.id == syncCalendarID else { return }
        syncCalendarID = ""
        syncCalendarName = ""
    }

    private func showCalendarError(_ error: Error) {
        exportAlert = ReminderExportAlert(
            title: "Unable to Update Calendar",
            message: error.localizedDescription
        )
    }

    private func performCalendarAutomation() async {
        do {
            _ = try WeekPlanAutomation.removeMealsAtStartOfNewWeekIfNeeded(in: modelContext)

            guard syncToICal,
                  let selectedSyncCalendar else {
                return
            }

            _ = try await WeekPlanAutomation.syncCurrentWeekCalendar(
                in: modelContext,
                to: selectedSyncCalendar
            )
        } catch {
            if let selectedSyncCalendar,
               let calendarError = error as? CalendarExportError,
               calendarError == .calendarUnavailable {
                forgetSyncCalendar(ifMatching: selectedSyncCalendar)
            }
        }
    }

    private func calendarMealTypeBinding(for mealType: MealType) -> Binding<Bool> {
        Binding {
            !excludedCalendarMealTypeIDs.contains(mealType.id)
        } set: { isIncluded in
            setCalendarMealType(mealType, isIncluded: isIncluded)
        }
    }

    private var calendarMealsWithoutMealTypeBinding: Binding<Bool> {
        Binding {
            !excludeCalendarMealsWithoutMealType
        } set: { isIncluded in
            excludeCalendarMealsWithoutMealType = !isIncluded
        }
    }

    private func setCalendarMealType(_ mealType: MealType, isIncluded: Bool) {
        var excludedIDs = excludedCalendarMealTypeIDs

        if isIncluded {
            excludedIDs.remove(mealType.id)
        } else {
            excludedIDs.insert(mealType.id)
        }

        excludedCalendarMealTypeIDsRaw = WeekPlanCalendarFilterDefaults.rawMealTypeIDs(from: excludedIDs)
    }
}

#Preview("Settings") {
    let previewData = PreviewData()

    WeekPlanSettingsView()
        .modelContainer(previewData.container)
}
