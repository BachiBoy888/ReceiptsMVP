//
//  ContentView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 16/9/25.
//

import SwiftUI
import VisionKit
import SwiftData
import os      // <— ДОБАВЬ (мы логируем из UI)


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.date, order: .reverse) var receipts: [Receipt]

    @State private var isScanning = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedReceipt: Receipt?    // для навигации к деталям
    @State private var lastURL: URL?

    let fetcher = ReceiptFetcher()

    var body: some View {
        NavigationStack {                                   // ⬅️ используем NavigationStack
            VStack(spacing: 0) {

                // Кнопка "Сканировать QR"
                Button {
                    isScanning = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Сканировать QR")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding([.horizontal, .top])

                // Индикатор загрузки поверх списка при парсинге
                ZStack(alignment: .top) {
                    // Список чеков
                    List(receipts) { r in
                        NavigationLink(destination: ReceiptDetailView(receipt: r)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.merchant.isEmpty ? "Неизвестно" : r.merchant).font(.headline)
                                Text(r.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text("Итого: \(r.total.doubleValue, format: twoFrac)")
                                    if let inn = r.inn, !inn.isEmpty { Text("ИНН \(inn)") }
                                }
                                .font(.footnote)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .padding(.top, 8)

                    if isLoading {
                        ProgressView("Загружаю чек…")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Мои чеки")
            // навигация к только что сохранённому чеку
            .navigationDestination(item: $selectedReceipt) { r in
                ReceiptDetailView(receipt: r)
            }
            // модальное окно со сканером
            .sheet(isPresented: $isScanning) {
                QRScannerView { url in
                    // закрываем сканер как только получили URL
                    isScanning = false
                    Task { await handleScanned(url: url) }
                }
                .ignoresSafeArea()
            }
            // алерт ошибок
            .alert("Ошибка",
                   isPresented: Binding(
                        get: { errorMessage != nil },
                        set: { if !$0 { errorMessage = nil } }
                   ),
                   actions: { Button("OK") { errorMessage = nil } },
                   message: { Text(errorMessage ?? "") })
        }
    }

    @MainActor
    private func handleScanned(url: URL) async {
        // простой дебаунс: не обрабатываем тот же URL подряд
        guard url != lastURL else { return }
        lastURL = url

        isLoading = true
        defer { isLoading = false }

        do {
            let parsed = try await fetcher.fetchAndParse(from: url)

            // сохраняем и получаем САМ объект Receipt
            let store = ReceiptStore(modelContext)
            let saved = try store.save(parsed: parsed, sourceURL: url)

            // переходим на экран деталей сохранённого чека
            selectedReceipt = saved

        } catch {
            if case ReceiptFetchError.parse(let snippet) = error {
                print("PARSE ERROR SNIPPET:\n\(snippet)")
                errorMessage = "Не удалось распознать чек. Разметка изменилась."
            } else if case ReceiptFetchError.badStatus(let code) = error {
                errorMessage = "Сервер вернул статус \(code)."
            } else {
                errorMessage = "Не удалось получить чек: \(error.localizedDescription)"
            }
        }
    }
}


// === File-scope helpers (ВНЕ struct/class) ===

let twoFrac: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))
