//
//  ImportAndResultViews.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

import SwiftUI
import UniformTypeIdentifiers
import Charts

// MARK: - ContentView

struct StatementsRootView: View {
    @State private var result: StatementResponse? = StatementStorage.load()
    @State private var isPicker = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            Group {
                if let r = result {
                    ResultView(
                        response: r,
                        onImportAgain: { isPicker = true },
                        onOpenLast: { if let last = StatementStorage.load() { result = last } },
                        onExportCSV: { exportCSV(r.transactions) }
                    )
                } else {
                    EmptyStateView(onImport: { isPicker = true })
                }
            }
            .navigationTitle("Мои чеки")
            .toolbar {
                if result != nil {
                    Button("Импортировать снова") { isPicker = true }
                }
            }
            .fileImporter(
                isPresented: $isPicker,
                allowedContentTypes: {
                    if let xls = UTType(filenameExtension: "xls") {
                        return [xls]
                    } else {
                        return [UTType(importedAs: "com.microsoft.excel.xls")]
                    }
                }(),
                allowsMultipleSelection: false
            ) { res in
                handlePick(res)
            }
            .overlay { if isLoading { ProgressView().controlSize(.large) } }
            .alert("Ошибка", isPresented: $isShowingError) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func handlePick(_ res: Result<[URL], Error>) {
        switch res {
        case .failure(let err):
            print("fileImporter error:", err)
            self.errorMessage = "Не удалось выбрать файл"
            self.isShowingError = true

        case .success(let urls):
            guard let url = urls.first else { return }
            guard let data = readPickedFileData(from: url) else {
                self.errorMessage = "Не удалось прочитать файл. Убедитесь, что выбран .xls из MBank."
                self.isShowingError = true
                return
            }
            Task {
                self.isLoading = true
                defer { self.isLoading = false }
                do {
                    let r = try await APIClient.shared.uploadXLS(data: data, filename: url.lastPathComponent)
#if DEBUG
                    DebugLog.response(r)
#endif
                    self.result = r
                    StatementStorage.save(r)
                } catch let e as APIError {
                    self.errorMessage = e.errorDescription ?? "Неизвестная ошибка."
                    self.isShowingError = true
                } catch {
                    self.errorMessage = error.localizedDescription   // <— вот это
                    self.isShowingError = true
                }
            }
        }
    }

    private func exportCSV(_ txs: [StatementResponse.Tx]) {
        let data = CSVBuilder.transactionsCSV(txs)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("transactions.csv")
        try? data.write(to: tmp, options: .atomic)
        presentShare(urls: [tmp]) // из ShareSheet+Network.swift
    }
}

private func readPickedFileData(from url: URL) -> Data? {
    let needsAccess = url.startAccessingSecurityScopedResource()
    defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xls")
    do {
        if FileManager.default.fileExists(atPath: tmp.path) {
            try FileManager.default.removeItem(at: tmp)
        }
        try FileManager.default.copyItem(at: url, to: tmp)
        let data = try Data(contentsOf: tmp)
        try? FileManager.default.removeItem(at: tmp)
        return data
    } catch {
        print("readPickedFileData error:", error)
        return nil
    }
}

// MARK: - EmptyState

struct EmptyStateView: View {
    let onImport: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Ещё нет данных — импортируйте .xls")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Импортировать .xls", action: onImport)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - ResultView

struct ResultView: View {
    let response: StatementResponse
    let onImportAgain: () -> Void
    let onOpenLast: () -> Void
    let onExportCSV: () -> Void

    @State private var metric: DisplayMetric = .debit // логичнее открыть “Списания” при таких данных

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Чип периода
                let chip = "\(DateFormatter.bishkekShort.string(from: response.period.from)) – \(DateFormatter.bishkekShort.string(from: response.period.to))"
                Text(chip)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.ultraThinMaterial).clipShape(Capsule())

                // Банк/валюта (если есть)
                if let account = response.account {
                    Text([account.bank, account.currency].compactMap{$0}.joined(separator: " — "))
                        .foregroundStyle(.secondary)
                }

                // Переключатель метрики
                Picker("Метрика", selection: $metric) {
                    ForEach(DisplayMetric.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                // Итог по выбранной метрике
                let total = response.totals.value(for: metric)
                Text("Итого: \(formatKGS(total))")
                    .font(.title3).bold()

                // График (используем dailySpending; если сервер шлёт только amount, он трактуется как дебет)
                SpendingChart(points: chartPointsFromServer(response, metric: metric), metric: metric)

                // Список транзакций
                VStack(alignment: .leading, spacing: 8) {
                    Text("Транзакции").font(.headline)

                    let filtered = filteredTransactions(response, metric: metric)

                    ForEach(filtered) { tx in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(DateFormatter.bishkekShort.string(from: tx.date)).font(.subheadline)
                                Text(tx.description).font(.body).lineLimit(3)
                            }
                            Spacer()
                            let v = valueForUI(tx, metric: metric)
                            Text(formatKGS(v))
                                .foregroundStyle(metric == .debit ? .red : (v < 0 ? .red : .green))
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }

                    if filtered.isEmpty {
                        Text("Нет операций для выбранной метрики.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }

                HStack {
                    Button("Импортировать снова", action: onImportAgain)
                    Button("Открыть прошлую выписку", action: onOpenLast)
                    Button("Экспорт CSV", action: onExportCSV)
                }.buttonStyle(.bordered)
            }
            .padding()
        }
        .onAppear { debugFilterCounts() }
        .onChange(of: metric) { _, _ in debugFilterCounts() }
    }

    // MARK: — Helpers

    private func derivedCredit(_ tx: StatementResponse.Tx) -> Double {
        if let c = tx.credit { return max(0, c) }
        if let a = tx.amount, a > 0 { return a }
        return 0
    }
    private func derivedDebit(_ tx: StatementResponse.Tx) -> Double {
        if let d = tx.debit { return max(0, d) }
        if let a = tx.amount, a < 0 { return abs(a) }
        return 0
    }
    private func valueForUI(_ tx: StatementResponse.Tx, metric: DisplayMetric) -> Double {
        switch metric {
        case .credit: return derivedCredit(tx)
        case .debit:  return derivedDebit(tx)
        case .net:    return derivedCredit(tx) - derivedDebit(tx)
        }
    }
    private func filteredTransactions(_ r: StatementResponse, metric: DisplayMetric) -> [StatementResponse.Tx] {
        let arr = r.transactions.filter { tx in
            switch metric {
            case .credit: return derivedCredit(tx) > 0
            case .debit:  return derivedDebit(tx)  > 0
            case .net:    return true
            }
        }
        return arr.sorted { $0.date > $1.date }
    }
    private func chartPointsFromServer(_ r: StatementResponse, metric: DisplayMetric) -> [ChartPoint] {
        // Daily.value(for:) у нас уже трактует amount как debit при отсутствии полей
        let cal = Calendar(identifier: .gregorian)
        var map: [Date: Double] = [:]
        for d in r.dailySpending {
            let day = cal.startOfDay(for: d.date)
            map[day] = d.value(for: metric)
        }
        var out: [ChartPoint] = []
        var cur = cal.startOfDay(for: r.period.from)
        let end = cal.startOfDay(for: r.period.to)
        while cur <= end {
            out.append(.init(date: cur, value: map[cur] ?? 0))
            cur = cal.date(byAdding: .day, value: 1, to: cur)!
        }
        return out
    }
    private func formatKGS(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = "KGS"; f.maximumFractionDigits = 2
        return f.string(from: v as NSNumber) ?? "\(v) KGS"
    }

    // Временный лог, чтобы сразу видеть, что фильтр сработал
    private func debugFilterCounts() {
        #if DEBUG
        let c = response.transactions.filter { derivedCredit($0) > 0 }.count
        let d = response.transactions.filter { derivedDebit($0)  > 0 }.count
        print("FILTER COUNTS → credit>0:", c, "debit>0:", d, "metric:", metric.rawValue)
        #endif
    }
}

// MARK: - Chart

struct ChartPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct SpendingChart: View {
    let points: [ChartPoint]
    let metric: DisplayMetric

    var body: some View {
        Chart(points) { p in
            BarMark(
                x: .value("Дата", p.date),
                y: .value(metric.rawValue, p.value)
            )
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
        .frame(height: 220)
    }
}
