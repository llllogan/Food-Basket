//
//  FoodBasketWidgetExtension.swift
//  FoodBasketWidgetExtension
//
//  Created by Logan Janssen | Codify on 11/6/2026.
//

import SwiftUI
import UIKit
import WidgetKit

struct FoodBasketNextMealProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FoodBasketNextMealEntry {
        FoodBasketNextMealEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            meal: .placeholder
        )
    }

    func snapshot(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> FoodBasketNextMealEntry {
        FoodBasketNextMealEntry(
            date: Date(),
            configuration: configuration,
            meal: nextMeal(for: configuration) ?? .placeholder
        )
    }

    func timeline(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> Timeline<FoodBasketNextMealEntry> {
        let now = Date()
        let entry = FoodBasketNextMealEntry(
            date: now,
            configuration: configuration,
            meal: nextMeal(for: configuration)
        )
        let refreshDate = Calendar.current.date(
            byAdding: .minute,
            value: 5,
            to: Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        ) ?? now.addingTimeInterval(4 * 60 * 60)

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func nextMeal(for configuration: ConfigurationAppIntent) -> FoodBasketWidgetPlannedMeal? {
        let selectedMealType = configuration.mealType.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesAllTypes = selectedMealType.isEmpty || selectedMealType == FoodBasketWidgetMealTypeOptionsProvider.allMealTypesTitle
        let today = Calendar.current.startOfDay(for: Date())

        return FoodBasketWidgetSnapshotStore.load()?.plannedMeals
            .filter { meal in
                Calendar.current.startOfDay(for: meal.plannedDate) >= today
            }
            .filter { meal in
                matchesAllTypes || meal.mealTypeName == selectedMealType
            }
            .sorted { lhs, rhs in
                if lhs.plannedDate != rhs.plannedDate {
                    return lhs.plannedDate < rhs.plannedDate
                }
                if lhs.portionSortOrder != rhs.portionSortOrder {
                    return lhs.portionSortOrder < rhs.portionSortOrder
                }
                return lhs.mealSortOrder < rhs.mealSortOrder
            }
            .first
    }
}

struct FoodBasketNextMealEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let meal: FoodBasketWidgetPlannedMeal?
}

struct FoodBasketWidgetExtensionEntryView: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: FoodBasketNextMealEntry

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                background
                    .frame(width: proxy.size.width, height: proxy.size.height)
                titleContent
                    .frame(width: proxy.size.width, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .containerBackground(for: .widget) {
            fallbackBackground
        }
    }

    @ViewBuilder
    private var background: some View {
        if let image = entry.meal?.image {
            image
                .resizable()
                .widgetAccentedRenderingMode(accentedImageRenderingMode)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            fallbackBackground
        }
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let mealTypeName = entry.meal?.mealTypeName {
                Text(mealTypeName)
                    .font(mealTypeFont)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
            }

            Text(entry.meal?.recipeName ?? "No meal planned")
                .font(titleFont)
                .fontWeight(.bold)
                .lineLimit(widgetFamily == .systemMedium ? 2 : 3)
                .minimumScaleFactor(0.76)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.85), radius: 3, y: 1)
                .widgetAccentable()
        }
        .padding(.horizontal, widgetFamily == .systemMedium ? 12 : 10)
        .padding(.vertical, widgetFamily == .systemMedium ? 10 : 8)
        .background(alignment: .leading) {
            textShadowBackdrop
                .widgetAccentable(false)
        }
        .padding(widgetFamily == .systemMedium ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var textShadowBackdrop: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(widgetRenderingMode == .fullColor ? 0.44 : 0.28))
                .blur(radius: 12)
                .padding(.horizontal, -12)
                .padding(.vertical, -8)

            Capsule()
                .fill(.black.opacity(widgetRenderingMode == .fullColor ? 0.28 : 0.18))
                .blur(radius: 22)
                .padding(.horizontal, -24)
                .padding(.vertical, -16)
        }
    }

    private var fallbackBackground: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    .white.opacity(widgetRenderingMode == .fullColor ? 0.36 : 0.18),
                    .white.opacity(0.06),
                    .black.opacity(widgetRenderingMode == .fullColor ? 0.16 : 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var accentedImageRenderingMode: WidgetAccentedRenderingMode {
        widgetRenderingMode == .fullColor ? .fullColor : .desaturated
    }

    private var mealTypeFont: Font {
        widgetFamily == .systemMedium ? .caption : .caption2
    }

    private var titleFont: Font {
        switch widgetFamily {
        case .systemMedium:
            .title2
        default:
            .headline
        }
    }
}

struct FoodBasketWidgetExtension: Widget {
    let kind = "FoodBasketWidgetExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: FoodBasketNextMealProvider()
        ) { entry in
            FoodBasketWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Next Meal")
        .description("Shows the next planned meal in Food Basket.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

private extension FoodBasketWidgetPlannedMeal {
    var image: Image? {
        guard let imageData,
              let uiImage = UIImage(data: imageData) else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    static var placeholder: FoodBasketWidgetPlannedMeal {
        FoodBasketWidgetPlannedMeal(
            id: UUID(),
            recipeID: UUID(),
            recipeName: "Tonight's dinner",
            plannedDate: Date(),
            dayOffset: 0,
            mealSortOrder: 0,
            portionSortOrder: 0,
            mealTypeID: nil,
            mealTypeName: "Dinner",
            imageData: nil
        )
    }
}

extension ConfigurationAppIntent {
    fileprivate static var allMeals: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.mealType = FoodBasketWidgetMealTypeOptionsProvider.allMealTypesTitle
        return intent
    }
}

#Preview(as: .systemSmall) {
    FoodBasketWidgetExtension()
} timeline: {
    FoodBasketNextMealEntry(
        date: .now,
        configuration: .allMeals,
        meal: .placeholder
    )
}

#Preview(as: .systemMedium) {
    FoodBasketWidgetExtension()
} timeline: {
    FoodBasketNextMealEntry(
        date: .now,
        configuration: .allMeals,
        meal: .placeholder
    )
}
