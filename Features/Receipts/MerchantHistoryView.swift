//
//  MerchantHistoryView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 18/9/25.
//

import SwiftUI
import SwiftData

struct MerchantHistoryView: View {
    // Контекст истории: либо по заведению, либо по компании
    private let keyVenue: String?
    private let keyCompany: String?

    @Query(sort: \Receipt.date, order: .reverse)
    private var allReceipts: [Receipt]

    private let twoFrac: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    // MARK: - Инициализаторы
    init(merchant: String, inn: String?) {
        self.keyCompany = merchant
        self.keyVenue = nil
    }

    init(venue: String) {
        self.keyVenue = venue
        self.keyCompany = nil
    }

    var body: some View {
        let receipts = filteredReceipts()
        let total = receipts.reduce(Decimal(0)) { $0 + $1.total }

        List {
            Section {
                HStack {
                    Text("Итого за весь период")
                    Spacer()
                    Text(total.doubleValue, format: twoFrac).bold()
                }
                Text("Покупок: \(receipts.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(receipts) { r in
                    NavigationLink(destination: ReceiptDetailView(receipt: r)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                            Text(shortLine(for: r))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(r.total.doubleValue, format: twoFrac)
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(titleText()) // ← контекст в заголовке
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func filteredReceipts() -> [Receipt] {
        if let v = keyVenue, !v.isEmpty {
            return allReceipts.filter { venueName(for: $0) == v }
        } else if let m = keyCompany, !m.isEmpty {
            return allReceipts.filter { $0.merchant == m }
        } else {
            return []
        }
    }

    private func titleText() -> String {
        if let v = keyVenue, !v.isEmpty { return "Заведение: \(v)" }
        if let m = keyCompany, !m.isEmpty { return "Организация: \(m)" }
        return "История покупок"
    }

    /// Подпись к строке истории
    private func shortLine(for r: Receipt) -> String {
        if keyVenue != nil {
            // в истории заведения показываем организацию
            return r.merchant.isEmpty ? "Организация: —" : "Организация: \(r.merchant)"
        } else {
            // в истории компании показываем заведение
            let v = venueName(for: r)
            return v.isEmpty ? "Заведение: —" : "Заведение: \(v)"
        }
    }

    /// Извлекаем название заведения из адреса
    private func venueName(for r: Receipt) -> String {
        if let address = r.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let first = address.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true).first {
                let name = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
        }
        return r.merchant // fallback
    }
}
