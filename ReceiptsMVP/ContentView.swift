//
//  ContentView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 16/9/25.
//

// Привет, это мой первый проект на SWIFT

import SwiftUI
import VisionKit
import SwiftData
import os      // <— ДОБАВЬ (мы логируем из UI)
import Charts

struct ReceiptSelection: Identifiable, Hashable {
    let id = UUID()
    let receipt: Receipt
}

struct DailySum: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let total: Double
}



struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.date, order: .reverse) var receipts: [Receipt]

    @State private var isScanning = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedReceipt: ReceiptSelection?   // было: Receipt?
    @State private var pendingReceipt: Receipt?            // ок
    @State private var lastURL: URL?

    let fetcher = ReceiptFetcher()

    private var chartDataLast60Days: [DailySum] {
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let filtered = receipts.filter { $0.date >= from }

        let grouped = Dictionary(grouping: filtered) { rec in
            cal.startOfDay(for: rec.date)
        }

        // заполним «пустые» дни нулями, чтобы график был непрерывным
        var allDays: [Date] = []
        var d = cal.startOfDay(for: from)
        let end = cal.startOfDay(for: Date())
        while d <= end {
            allDays.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }

        return allDays.map { day in
            let sumDec = grouped[day]?.reduce(Decimal(0), { $0 + $1.total }) ?? 0
            return DailySum(date: day, total: sumDec.doubleValue)
        }
    }

    private var totalFor60Days: Double {
        chartDataLast60Days.reduce(0) { $0 + $1.total }
    }
    
    var body: some View {
        NavigationStack {                                   // ⬅️ используем NavigationStack
            // График расходов за 60 дней
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Расходы (последние 2 месяца)")
                        .font(.headline)
                    Spacer()
                    Text(totalFor60Days, format: .currency(code: Locale.current.currency?.identifier ?? "KGS"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if chartDataLast60Days.isEmpty {
                    // Плейсхолдер, когда чеков ещё нет
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                        Text("Пока нет данных — отсканируйте первый чек")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(height: 140)
                    .padding(.horizontal)
                    .padding(.top, 8)
                } else {
                    Chart(chartDataLast60Days) { point in
                        BarMark(
                            x: .value("Дата", point.date, unit: .day),
                            y: .value("Сумма", point.total)
                        )
                    }
                    // Тики по оси X раз в неделю — чище выглядит
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 180)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.25), value: chartDataLast60Days)
                }
            }
            .padding(.top, 12)

            
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
            .navigationDestination(item: $selectedReceipt) { sel in
                ReceiptDetailView(receipt: sel.receipt)
            }
            // модальное окно со сканером
            .sheet(isPresented: $isScanning) {
                QRScanSheet { url, image in
                    isScanning = false
                    Task { await handleScanned(url: url, photo: image) }   // ← передаём фото
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
            
            .onChange(of: isScanning) { _, newValue in
                if !newValue, let r = pendingReceipt {
                    selectedReceipt = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selectedReceipt = ReceiptSelection(receipt: r)  // всегда новый UUID
                        pendingReceipt = nil
                    }
                }
            }

        }
    }

    @MainActor
    private func handleScanned(url: URL, photo: UIImage?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let parsed = try await fetcher.fetchAndParse(from: url)
            let store = ReceiptStore(modelContext)
            let (saved, _) = try store.saveOrUpdate(parsed: parsed, sourceURL: url, photo: photo)
            pendingReceipt = saved   // навигация сработает в .onChange закрытия шторки
        } catch {
            errorMessage = "Не удалось получить чек: \(error.localizedDescription)"
        }
    }
    
    
}


// === File-scope helpers (ВНЕ struct/class) ===

let twoFrac: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))
