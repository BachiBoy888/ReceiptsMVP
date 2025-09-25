//
//  MatchBadge.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Features/Statements/Views/MatchBadge.swift
import SwiftUI

struct MatchBadge: View {
    var body: some View {
        Label("Чек", systemImage: "doc.text")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())
    }
}
