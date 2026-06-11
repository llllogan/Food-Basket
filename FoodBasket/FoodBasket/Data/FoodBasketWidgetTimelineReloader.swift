//
//  FoodBasketWidgetTimelineReloader.swift
//  Food Basket
//
//  Created by Codex on 11/6/2026.
//

#if canImport(WidgetKit)
import WidgetKit
#endif

enum FoodBasketWidgetTimelineReloader {
    static func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
