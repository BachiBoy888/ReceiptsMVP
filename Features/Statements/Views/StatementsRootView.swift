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
            HStack {
                    Text("Мои транзакции")
                        .font(.largeTitle).bold()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
            Group {
                    if let r = result {
                        ResultView(
                            response: r,
                            onImportAgain: { isPicker = true },
                            onOpenLast: { if let last = StatementStorage.load() { result = last } },
                            onExportCSV: { exportCSV(r.transactions) },
                            isLoading: isLoading
                        )
                    } else {
                        EmptyStateView(onImport: { isPicker = true })
                    }
                }
            .toolbar(.hidden, for: .navigationBar)
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
                if let r = self.result {
                    if let first = r.transactions.first {
                        print("DEBUG ts(first) =>", DateFormatter.bishkekDateTime.string(from: first.ts))
                    }
                    print("DEBUG cumulativeClose(first) =>", r.dailySpending.first?.cumulativeClose as Any)
                    print("DEBUG timeline points =>", r.timeline?.count ?? 0)
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

            Button(action: onImport) {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Загрузить выписку из MBank (.xls)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 4)
        }
        .padding()
    }
}


// MARK: - ResultView

struct ResultView: View {

    @Environment(\.modelContext) private var modelContext

    @StateObject private var matchStore = ReceiptMatchStore()
    private let matcher = ReceiptMatcher()

    @State private var receipts: [ReceiptTicket] = []
    @State private var receiptByTicketId: [UUID: Receipt] = [:]

    // Обёртка для навигации, если у Receipt нет явного Identifiable
    struct ReceiptRef: Identifiable {
        let id: String        // customId
        let receipt: Receipt
    }
    @State private var pushReceipt: ReceiptRef?

    let response: StatementResponse
    let onImportAgain: () -> Void
    let onOpenLast: () -> Void
    let onExportCSV: () -> Void
    let isLoading: Bool

    @State private var metric: DisplayMetric = .debit

    // MARK: — Data refresh

    private func reloadReceiptsAndIndex() {
        do {
            let loaded = try ReceiptStorageBridge.loadAllReceiptsWithMapping(context: modelContext)
            self.receipts = loaded.tickets
            self.receiptByTicketId = loaded.byTicketId
            matcher.rebuildIndex(loaded.tickets)
            #if DEBUG
            print("DEBUG receipts reloaded:", loaded.tickets.count)
            #endif
        } catch {
            self.receipts = []
            self.receiptByTicketId = [:]
            matcher.rebuildIndex([])
            #if DEBUG
            print("DEBUG receipts reload error:", error)
            #endif
        }
    }

    private func relinkAll() {
        let txs = response.transactions
        var newLinks = 0
        for tx in txs {
            let model = toTransaction(tx)
            if matchStore.get(model.id) != nil { continue }
            if let auto = matcher.match(model),
               let _ = receiptByTicketId[auto.receiptId] {
                matchStore.set(model.id, match: auto)
                newLinks += 1
            }
        }
        #if DEBUG
        print("DEBUG relinkAll newLinks:", newLinks)
        #endif
    }

    // MARK: — Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Переключатель метрики
                Picker("Метрика", selection: $metric) {
                    ForEach(DisplayMetric.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                // Итог за период
                let total = response.totals.value(for: metric)
                HStack {
                    Text("Итого за период").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(formatKGS(total)).font(.system(size: 22, weight: .bold)).monospacedDigit()
                }

                // График
                ZStack {
                    if metric == .net {
                        Chart(chartPointsCumulativeFromServer(response)) { p in
                            LineMark(
                                x: .value("День", p.date),
                                y: .value("Кумулятив", p.value)
                            )
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .id("cum")
                    } else {
                        SpendingChartDailyBars(
                            points: chartPointsFromServer(response, metric: metric),
                            period: (start: response.period.from, end: response.period.to),
                            title: metric.rawValue
                        )
                        .id("bars-\(metric.rawValue)")
                    }

                    if isLoading {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.08))
                            .allowsHitTesting(false)
                        ProgressView().controlSize(.large).tint(.blue)
                    }
                }

                // Кнопка импорта
                Button { onImportAgain() } label: {
                    HStack(spacing: 8) { Image(systemName:"tray.and.arrow.down"); Text("Загрузить выписку из MBank (.xls)") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)

                // Список транзакций (с группировкой)
                VStack(alignment: .leading, spacing: 12) {
                    let groups = dayGroups(response, metric: metric)

                    if groups.isEmpty {
                        Text("Нет операций для выбранной метрики.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    } else {
                        ForEach(groups, id: \.day) { group in
                            // Заголовок дня
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

                            // Итого за день
                            HStack {
                                Text("Итого за день")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let daySum = group.items.reduce(0.0) { $0 + valueForUI($1, metric: metric) }
                                Text(formatKGS(daySum))
                                    .font(.caption.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 2)

                            // Элементы дня
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(group.items) { tx in
                                    let model = toTransaction(tx)
                                    let hasMatch = matchStore.get(model.id) != nil

                                    HStack(alignment: .center, spacing: 12) {
                                        Rectangle()
                                            .frame(width: 4, height: 32)
                                            .foregroundStyle(hasMatch ? .green : .clear)
                                            .opacity(hasMatch ? 1 : 0.15)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(DateFormatter.bishkekTime.string(from: tx.ts))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)

                                            HStack(spacing: 8) {
                                                Text(tx.description)
                                                    .font(.body)
                                                    .lineLimit(2)

                                                if hasMatch {
                                                    MatchBadge()
                                                }
                                            }
                                        }

                                        Spacer()

                                        let v = valueForUI(tx, metric: metric)
                                        Text(formatKGS(v))
                                            .font(.body.monospacedDigit())
                                            .foregroundStyle(metric == .debit ? .yellow : (v < 0 ? .yellow : .green))

                                        if hasMatch {
                                            Image(systemName: "chevron.right")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 6)
                                    .background(
                                        (hasMatch ? Color.green.opacity(0.15) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    )
                                    .contentShape(Rectangle())
                                    .accessibilityAddTraits(hasMatch ? .isButton : [])
                                    .onTapGesture {
                                        guard hasMatch else { return }

                                        if let match = matchStore.get(model.id),
                                           let receipt = receiptByTicketId[match.receiptId] {
                                            pushReceipt = ReceiptRef(id: receipt.customId, receipt: receipt)
                                            return
                                        }

                                        if let auto = matcher.match(model),
                                           let receipt = receiptByTicketId[auto.receiptId] {
                                            matchStore.set(model.id, match: auto)
                                            pushReceipt = ReceiptRef(id: receipt.customId, receipt: receipt)
                                            return
                                        }
                                    }

                                    Divider()
                                        .opacity(tx.id == group.items.last?.id ? 0 : 1)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding()
        }
        // 🔻 Все модификаторы View — здесь, на одном уровне
        .onAppear {
            debugFilterCounts()
            reloadReceiptsAndIndex()
            relinkAll()
        }
        .onChange(of: metric) { _, _ in
            debugFilterCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptsDidChange)) { _ in
            reloadReceiptsAndIndex()
            relinkAll()
        }
        .onChange(of: response.transactions.count) { _, _ in
            relinkAll()
        }
        .sheet(item: $pushReceipt) { ref in
            ReceiptDetailView(receipt: ref.receipt)
        }
    }

    // MARK: — Helpers (как у тебя было)

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
        return arr.sorted { $0.ts > $1.ts }
    }
    private func chartPointsFromServer(_ r: StatementResponse, metric: DisplayMetric) -> [ChartPoint] {
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
    private func chartPointsCumulativeFromServer(_ r: StatementResponse) -> [ChartPoint] {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: r.period.from)
        let end   = cal.startOfDay(for: r.period.to)

        let hasCum = r.dailySpending.contains { $0.cumulativeClose != nil }

        var byDay: [Date: StatementResponse.Daily] = [:]
        for d in r.dailySpending {
            byDay[cal.startOfDay(for: d.date)] = d
        }

        var out: [ChartPoint] = []
        var cur = start
        var running: Double = 0

        while cur <= end {
            if hasCum, let y = byDay[cur]?.cumulativeClose {
                running = y
            } else {
                let dayNet = byDay[cur]?.value(for: .net) ?? 0
                running += dayNet
            }
            out.append(.init(date: cur, value: running))
            cur = cal.date(byAdding: .day, value: 1, to: cur)!
        }
        return out
    }

    private func debugFilterCounts() {
        #if DEBUG
        let c = response.transactions.filter { derivedCredit($0) > 0 }.count
        let d = response.transactions.filter { derivedDebit($0)  > 0 }.count
        print("FILTER COUNTS → credit>0:", c, "debit>0:", d, "metric:", metric.rawValue)
        #endif
    }

    private func dayGroups(_ r: StatementResponse, metric: DisplayMetric) -> [(day: Date, items: [StatementResponse.Tx])] {
        let arr = filteredTransactions(r, metric: metric)
        let cal = Calendar(identifier: .gregorian)
        let grouped = Dictionary(grouping: arr) { cal.startOfDay(for: $0.ts) }
        let sortedDays = grouped.keys.sorted(by: >)
        return sortedDays.map { day in
            let items = grouped[day]!.sorted { $0.ts > $1.ts }
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
}

// MARK: - Chart

struct ChartPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}
