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
import os
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

    enum SpendPeriod: String, CaseIterable, Identifiable {
        case thisMonth = "Этот месяц"
        case lastMonth = "Прошлый месяц"
        case lastTwoMonths = "за 30 дней"
        var id: Self { self }
    }

    @State private var selectedPeriod: SpendPeriod = .lastTwoMonths
    @State private var isScanning = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingSelection: ReceiptSelection?
    @State private var lastURL: URL?

    let fetcher = ReceiptFetcher()

    private var chartDataLast60Days: [DailySum] {
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let filtered = receipts.filter { $0.date >= from }
        let grouped = Dictionary(grouping: filtered) { rec in cal.startOfDay(for: rec.date) }

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
        NavigationStack {
            // Заголовок вне скролла
            HStack {
                Text("Мои чеки")
                    .font(.largeTitle).bold()
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            // Всё остальное — единый ScrollView
            ScrollView {
                // ===== Верхний блок: период + сумма + график =====
                VStack(alignment: .leading, spacing: 12) {

                    // Переключатель периода
                    Picker("Период", selection: $selectedPeriod) {
                        ForEach(SpendPeriod.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Сумма за период
                    let total = totalAmount(in: selectedPeriod).doubleValue
                    HStack {
                        Text("Затраты за период")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(total, format: kgsFmt)
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                    }

                    // График
                    let bins = dayBins(for: selectedPeriod)
                    if bins.isEmpty {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(.ultraThinMaterial)
                            Text("Нет данных за выбранный период")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 160)
                    } else {
                        let (start, end) = periodRange(selectedPeriod)
                        let maxY = max(bins.map { $0.amount }.max() ?? 0, 1)
                        let paddedMaxY = maxY * 1.2
                        let count = bins.count
                        let barWidth: CGFloat = count > 45 ? 4 : (count > 30 ? 6 : 8)

                        Chart(bins) { bin in
                            BarMark(
                                x: .value("Дата", bin.day),
                                y: .value("Сумма", bin.amount),
                                width: .fixed(barWidth)
                            )
                            .cornerRadius(3)
                        }
                        .chartXScale(domain: start...end)
                        .chartYScale(domain: 0...paddedMaxY)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 10)) { value in
                                if let date = value.as(Date.self) {
                                    let s = Calendar.current.startOfDay(for: start)
                                    let idx = Calendar.current.dateComponents([.day], from: s, to: date).day ?? 0
                                    if idx % 2 == 0 {
                                        AxisGridLine().foregroundStyle(.gray.opacity(0.3))
                                        AxisTick(length: 4)
                                        AxisValueLabel {
                                            Text(date, format: Date.FormatStyle().day().month(.abbreviated))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                                AxisGridLine().foregroundStyle(.gray.opacity(0.3))
                                AxisTick(length: 4)
                                AxisValueLabel {
                                    if let d = value.as(Double.self) {
                                        let whole = Int(d)
                                        if d == Double(whole) {
                                            Text("\(whole)")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text(d, format: .number.precision(.fractionLength(2)))
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .chartPlotStyle { plot in
                            plot
                                .padding(.leading, 6)
                                .padding(.trailing, 6)
                                .padding(.top, 0)
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    }
                }
                .padding([.horizontal, .top])

                // ===== Кнопка "Сканировать QR" =====
                Button {
                    isScanning = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Сканировать QR на чеке")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding([.horizontal, .top])

                // ===== Список чеков (вместо List) + лоудер поверх =====
                ZStack(alignment: .top) {
                    LazyVStack(spacing: 0) {
                        let groups = groupedReceiptsByDay()

                        if groups.isEmpty {
                            Text("Чеки пока не добавлены")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(groups, id: \.day) { group in
                                // Заголовок дня — «пилюля» по центру
                                HStack {
                                    Spacer()
                                    Text(dayTitle(group.day))
                                        .font(.caption).bold()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                
                                /// ⬇️ ДОБАВЬ ЭТО: "Итого за день" по чекам
                                HStack {
                                    Text("Итого за день")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    let daySum = group.items.reduce(Decimal(0)) { $0 + $1.total }.doubleValue
                                    Text(daySum, format: kgsFmt)
                                        .font(.caption.bold())
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 4)
                                .padding(.bottom, 2)

                                // Элементы дня
                                VStack(spacing: 4) {
                                    ForEach(group.items) { r in
                                        NavigationLink(destination: ReceiptDetailView(receipt: r)) {
                                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    // маленькое время — как в чатах
                                                    Text(r.date.formatted(date: .omitted, time: .shortened))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)

                                                    Text(venueName(for: r))
                                                        .font(.body)
                                                        .lineLimit(2)
                                                }

                                                Spacer()

                                                // сумма + стрелка справа
                                                HStack(spacing: 6) {
                                                    Text(r.total.doubleValue, format: twoFrac)
                                                        .font(.body.monospacedDigit())
                                                        .foregroundStyle(.primary)

                                                    Image(systemName: "chevron.right")
                                                        .font(.footnote.weight(.semibold))
                                                        .foregroundStyle(.tertiary)
                                                        .accessibilityHidden(true)
                                                }
                                            }
                                            .contentShape(Rectangle())
                                            .accessibilityAddTraits(.isButton)
                                        }
                                        .buttonStyle(PressableRowStyle())    // ← фон-карточка + анимация нажатия
                                        .padding(.bottom, 8)                 // вместо Divider — воздух между карточками


                                        // Разделитель между элементами дня (без последнего)
                                        if r.id != group.items.last?.id {
                                 
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $pendingSelection) { sel in
                ReceiptDetailView(receipt: sel.receipt)
            }
            .sheet(isPresented: $isScanning) {
                QRScanSheet { url, image in
                    isScanning = false
                    Task { await handleScanned(url: url, photo: image) }
                }
                .ignoresSafeArea()
            }
            .alert(
                "Ошибка",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: { Button("OK") { errorMessage = nil } },
                message: { Text(errorMessage ?? "") }
            )
        }
    }

    // MARK: - functions

    @MainActor
    private func handleScanned(url: URL, photo: UIImage?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let parsed = try await fetcher.fetchAndParse(from: url)
            let store = ReceiptStore(modelContext)
            let (saved, _) = try store.saveOrUpdate(parsed: parsed, sourceURL: url, photo: photo)
            pendingSelection = nil
            DispatchQueue.main.async {
                pendingSelection = ReceiptSelection(receipt: saved)
            }
        } catch {
            errorMessage = "Не удалось получить чек: \(error.localizedDescription)"
        }
    }

    private func groupedReceiptsByDay() -> [(day: Date, items: [Receipt])] {
        let cal = Calendar(identifier: .gregorian)

        // сгруппировать по началу дня
        let grouped = Dictionary(grouping: receipts) { r in
            cal.startOfDay(for: r.date)
        }

        // дни по убыванию
        let days = grouped.keys.sorted(by: >)

        // внутри дня — по времени по убыванию
        return days.map { day in
            let items = (grouped[day] ?? []).sorted(by: { $0.date > $1.date })
            return (day: day, items: items)
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let d = cal.startOfDay(for: day)

        if d == today { return "Сегодня" }
        if d == cal.date(byAdding: .day, value: -1, to: today) { return "Вчера" }
        return DateFormatter.bishkekLong.string(from: d)
    }
    
    
    
    private func venueName(for r: Receipt) -> String {
        if let address = r.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let first = address.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true).first
            let name = String(first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return r.merchant.isEmpty ? "Неизвестно" : r.merchant
    }

    private func periodRange(_ p: SpendPeriod, now: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        switch p {
        case .thisMonth:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        case .lastMonth:
            let startOfThis = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: .month, value: -1, to: startOfThis)!
            return (start, startOfThis)
        case .lastTwoMonths:
            let startOfThis = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: .month, value: -1, to: startOfThis)!
            let end = cal.date(byAdding: .month, value: 1, to: startOfThis)!
            return (start, end)
        }
    }

    private func receipts(in period: SpendPeriod) -> [Receipt] {
        let (start, end) = periodRange(period)
        return receipts.filter { $0.date >= start && $0.date < end }
    }

    private func totalAmount(in period: SpendPeriod) -> Decimal {
        receipts(in: period).reduce(Decimal(0)) { $0 + $1.total }
    }

    private struct DayPoint: Identifiable { let id = UUID(); let day: Date; let amount: Double }

    private func chartPoints(for period: SpendPeriod) -> [DayPoint] {
        let cal = Calendar.current
        let periodReceipts = receipts(in: period)
        let grouped = Dictionary(grouping: periodReceipts) { r in cal.startOfDay(for: r.date) }
        return grouped.keys.sorted().map { day in
            let daySum = grouped[day]!.reduce(Decimal(0)) { $0 + $1.total }
            return DayPoint(day: day, amount: daySum.doubleValue)
        }
    }

    private struct DayBin: Identifiable { let id = UUID(); let day: Date; let amount: Double }

    private func dayBins(for period: SpendPeriod) -> [DayBin] {
        let cal = Calendar.current
        let (start, end) = periodRange(period)
        let grouped = Dictionary(grouping: receipts.filter { $0.date >= start && $0.date < end }) { r in
            cal.startOfDay(for: r.date)
        }
        let sumByDay: [Date: Double] = grouped.mapValues { arr in
            arr.reduce(Decimal(0)) { $0 + $1.total }.doubleValue
        }

        var bins: [DayBin] = []
        var d = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        while d < endDay {
            let amount = sumByDay[d] ?? 0
            bins.append(DayBin(day: d, amount: amount))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return bins
    }
}

// === File-scope helpers ===
let twoFrac: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))
private let kgsFmt: FloatingPointFormatStyle<Double>.Currency =
    .currency(code: "KGS").precision(.fractionLength(2))
