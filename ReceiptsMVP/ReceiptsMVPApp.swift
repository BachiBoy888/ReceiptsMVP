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
            ContentView()
        }
        .modelContainer(for: [Receipt.self]) // ✅ обязателен
    }
}
