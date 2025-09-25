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
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Receipt.self]) // ✅ обязателен
    }
}
