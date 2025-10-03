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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var selectedPeriod: SpendPeriod = .lastTwoMonths
    @State private var isScanning = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingSelection: ReceiptSelection?
    @State private var lastURL: URL?
    @State private var showFeedback = false    // ⬅️ добавь это
    

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
                Button {
                    // ✅ Amplitude: шторка обратной связи открыта
                       AnalyticsService.shared.track("feedback_sheet_opened")
                    showFeedback = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3.weight(.semibold))
                }
                .accessibilityLabel("Оставить обратную связь")
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
            .onAppear {
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackSheetView(onInstruction: {
                    showOnboarding = true
                })
            }
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

            // ✅ Amplitude: чек успешно отсканирован
            AnalyticsService.shared.track(AnalyticsEvent.receiptScanned, props: [
                "date": saved.date.ISO8601Format(),
                "merchant": saved.merchant,
                "total": saved.total.doubleValue,
                "source": "qr" // или "camera" / "photo_import" если различаешь
            ])

        } catch {
            // ✅ (опционально) событие ошибки сканирования
            AnalyticsService.shared.track("receipt_scan_failed", props: [
                "reason": error.localizedDescription,
                "url_host": url.host()
            ])
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


struct FeedbackSheetView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    // новый колбэк для запуска онбординга
    var onInstruction: () -> Void = {}

    private let waURL = URL(string: "https://wa.me/996220447446?text=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82!%20%F0%9F%91%8B%20%D1%8F%20%D0%BF%D0%BE%D0%BB%D1%8C%D0%B7%D1%83%D1%81%D1%8C%20%D0%B2%D0%B0%D1%88%D0%B8%D0%BC%20%D0%BF%D1%80%D0%B8%D0%BB%D0%BE%D0%B6%D0%B5%D0%BD%D0%B8%D0%B5%D0%BC%20%22%D0%9C%D0%BE%D0%B8%20%D1%87%D0%B5%D0%BA%D0%B8%22")!

    var body: some View {
        VStack(spacing: 20) {
            Text("Спасибо, что установили наше приложение.")
                .font(.title3).bold()
                .multilineTextAlignment(.center)

            Text("Мы хотим, чтобы приложение становилось лучше, поэтому нам важно получать от вас обратную связь.")
                .multilineTextAlignment(.center)

            Button {
                // ✅ Amplitude: клик «написать разработчикам»
                    AnalyticsService.shared.track(AnalyticsEvent.devContactLinkClicked, props: [
                        "channel": "whatsapp",
                        "pre_filled": true
                    ])
                openURL(waURL)
            } label: {
                Text("Написать разработчикам")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green.opacity(0.9))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityLabel("Написать в WhatsApp разработчикам")

            // ⬇️ новая кнопка «Инструкция»
            Button {
                // ✅ Amplitude: повторное открытие инструкции
                    AnalyticsService.shared.track(AnalyticsEvent.helpInstructionOpened, props: [
                        "entry_point": "feedback_sheet",
                        "repeat": true
                    ])
                dismiss()               // закрыть шторку
                onInstruction()         // открыть онбординг
            } label: {
                Text("Инструкция")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.secondary.opacity(0.4), lineWidth: 1)
                    )
            }
            .accessibilityLabel("Открыть инструкцию")

            Spacer(minLength: 0)
        }
        .padding()
        .presentationDetents([.fraction(0.35), .medium])
        .presentationDragIndicator(.visible)
    }
}
