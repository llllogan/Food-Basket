//
//  ThisWeekSettingsGroup.swift
//  Food Basket
//
//  Created by Codex on 20/6/2026.
//

import SwiftUI

struct ThisWeekSettingsGroup: View {
    let mealTypes: [MealType]
    @Binding var removeMealsAtNewWeek: Bool
    @Binding var weekStartDay: Int
    @Binding var excludedCalendarMealTypeIDsRaw: String
    @Binding var excludeCalendarMealsWithoutMealType: Bool
    let onOpenThisWeekCalendar: () -> Void

    private var excludedCalendarMealTypeIDs: Set<UUID> {
        WeekPlanCalendarFilterDefaults.mealTypeIDs(from: excludedCalendarMealTypeIDsRaw)
    }

    var body: some View {
        List {
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
                calendarViewHeader
            } footer: {
                Text("Only selected meal types appear in the This Week calendar view.")
            }

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
        .navigationTitle("This Week Settings")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .listStyle(.insetGrouped)
    }

    private var calendarViewHeader: some View {
        HStack {
            Text("Calendar View")
            Spacer()
            Button(action: onOpenThisWeekCalendar) {
                Text("View")
                    .font(.subheadline.bold())
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
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
