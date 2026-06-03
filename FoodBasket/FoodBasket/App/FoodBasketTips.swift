//
//  FoodBasketTips.swift
//  Food Basket
//
//  Created by Codex on 3/6/2026.
//

import SwiftUI
import TipKit

struct AddGroceriesToRemindersTip: Tip {
    var id: String {
        "add-groceries-to-reminders"
    }

    var title: Text {
        Text("Add groceries to Reminders")
    }

    var message: Text? {
        Text("Use the share button to add this week's grocery items to any Reminders list you choose.")
    }

    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }

    var options: [Option] {
        MaxDisplayCount(1)
        IgnoresDisplayFrequency(true)
    }
}
