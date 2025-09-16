//
//  ReceiptDetailView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import SwiftUI
import SafariServices

struct ReceiptDetailView: View {
    let receipt: Receipt
    @State private var showSafari = false

    private let twoFrac: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Основная информация
                Text(receipt.merchant.isEmpty ? "Неизвестно" : receipt.merchant)
                    .font(.title2).bold()

                if let inn = receipt.inn, !inn.isEmpty {
                    Text("ИНН: \(inn)")
                }
                if let address = receipt.address, !address.isEmpty {
                    Text(address)
                }

                Text("Дата: \(receipt.date.formatted(date: .long, time: .standard))")

                Text("Итого: \(receipt.total.doubleValue, format: twoFrac)")
                    .bold()
                    .padding(.top, 4)

                // Список позиций
                if let json = receipt.itemsJSON,
                   let data = json.data(using: .utf8),
                   let items = try? JSONDecoder().decode([ParsedItem].self, from: data),
                   !items.isEmpty {

                    Divider().padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(idx + 1). \(it.name)")
                                Text("Цена: \(it.price.doubleValue, format: twoFrac) × \(it.qty.doubleValue, format: twoFrac) = \(it.sum.doubleValue, format: twoFrac)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // QR-код (после списка позиций)
                if !receipt.sourceURL.isEmpty {
                    Divider().padding(.vertical, 8)

                    VStack(spacing: 8) {
                        Text("QR из чека")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        QRCodeView(string: receipt.sourceURL, size: 180)
                            .onTapGesture { showSafari = true }
                            .accessibilityAddTraits(.isButton)

                        Text("Нажмите на QR, чтобы открыть сайт налоговой")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Чек")
        .sheet(isPresented: $showSafari) {
            Group {
                if let validURL = URL(string: receipt.sourceURL) {
                    SFSafariView(url: validURL)
                } else {
                    Text("Некорректная ссылка")
                }
            }
        }
    }
}

// Safari wrapper
struct SFSafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
