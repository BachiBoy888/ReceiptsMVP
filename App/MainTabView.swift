//
//  MainTabView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 25/9/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // твой существующий экран чеков
            ContentView()
                .tabItem { Label("Мои чеки", systemImage: "receipt") }

            // вкладка выписок (из Statements)
            StatementsRootView()
                .tabItem { Label("Мои транзакции", systemImage: "doc.text.magnifyingglass") }
        }
    }
}

