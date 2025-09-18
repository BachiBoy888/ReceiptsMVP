//
//  MerchantHistoryView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 18/9/25.
//

import SwiftUI
import SwiftData

struct MerchantHistoryView: View {
    let merchant: String
    let inn: String?

    @Environment(\.modelContext) private var modelContext
    @State private var receipts: [Receipt] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let twoFrac: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    var body: some View {
        List {
            // Сводка
            if !receipts.isEmpty {
                Section {
                    HStack {
                        Text("Всего чеков")
                        Spacer()
                        Text("\(receipts.count)")
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Итого за период")
                        Spacer()
                        Text(totalSum.doubleValue, format: twoFrac)
                            .fontWeight(.semibold)
                    }
                }
            }

            // История: по каждому чеку — «Открыть чек» + позиции
            ForEach(receipts) { r in
                Section {
                    // 👉 Кнопка-переход к деталям конкретного чека
                    NavigationLink {
                        ReceiptDetailView(receipt: r)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Открыть чек")
                            Spacer()
                            Text(r.total.doubleValue, format: .number.precision(.fractionLength(2)))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Позиции (если есть)
                    if let items = decodeItems(r), !items.isEmpty {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(it.name).font(.subheadline)
                                Text("Кол-во: \(it.qty.doubleValue, format: .number.precision(.fractionLength(2))) · Сумма: \(it.sum.doubleValue, format: .number.precision(.fractionLength(2)))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        // если позиций нет — покажем только итог
                        Text("Сумма чека: \(r.total.doubleValue, format: .number.precision(.fractionLength(2)))")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    // Заголовок секции — дата чека
                    Text(r.date.formatted(date: .long, time: .shortened))
                } footer: {
                    Text("Итого по чеку: \(r.total.doubleValue, format: .number.precision(.fractionLength(2)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .overlay {
            if isLoading {
                ProgressView("Загружаю историю…")
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button("Повторить") { Task { await load() } }
                }
            } else if receipts.isEmpty {
                ContentUnavailableView(
                    "Нет покупок",
                    systemImage: "cart",
                    description: Text("Пока нет чеков для этого продавца")
                )
            }
        }
        .navigationTitle(titleText)
        .task { await load() }
    }

    private var titleText: String {
        if let inn, !inn.isEmpty {
            return "\(merchant.isEmpty ? "Продавец" : merchant) — ИНН \(inn)"
        } else {
            return merchant.isEmpty ? "История покупок" : merchant
        }
    }

    private var totalSum: Decimal {
        receipts.reduce(0) { $0 + $1.total }
    }

    private func decodeItems(_ r: Receipt) -> [ParsedItem]? {
        guard let json = r.itemsJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([ParsedItem].self, from: data)
    }

    @MainActor
    private func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            if let inn, !inn.isEmpty {
                // ✅ Можно фильтровать в предикате
                let descriptor = FetchDescriptor<Receipt>(
                    predicate: #Predicate { $0.inn == inn },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                receipts = try modelContext.fetch(descriptor)
            } else {
                // ❗️Нельзя lowercased() в предикате — берём все и фильтруем в памяти.
                let descriptor = FetchDescriptor<Receipt>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let all = try modelContext.fetch(descriptor)
                let target = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
                receipts = all.filter { rec in
                    rec.merchant.compare(target, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
            }
            errorMessage = nil
        } catch let err {
            errorMessage = err.localizedDescription
            receipts = []
        }
    }
}
