//
//  ReceiptsMVPApp.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 16/9/25.
//

import SwiftUI
import SwiftData

@main
struct ReceiptsMVPApp: App {

    init() {
        _ = AnalyticsService.shared
        AnalyticsService.shared.track("debug_app_launched", props: [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "env": "dev"
        ])
// ← инициализация Amplitude однажды при запуске
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    AnalyticsService.shared.trackScreen("MainTabView")
                }
        }
        .modelContainer(for: [Receipt.self])
    }
}
