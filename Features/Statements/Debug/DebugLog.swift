//
//  DebugLog.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

// DebugLog.swift
import Foundation

#if DEBUG
enum DebugLog {
    static func response(_ r: StatementResponse) {
        let df = DateFormatter()
        df.timeZone = TimeZone(identifier: "Asia/Bishkek")
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "yyyy-MM-dd"

        print("===== API RESPONSE SUMMARY =====")
        if let acc = r.account {
            print("Account:", acc.bank ?? "—", "|", acc.currency)
        }
        print("Period:", df.string(from: r.period.from), "→", df.string(from: r.period.to))
        print("dailySpending.count:", r.dailySpending.count, "| transactions.count:", r.transactions.count)

        // Totals
        let credits = r.totals.value(for: .credit)
        let debits  = r.totals.value(for: .debit)
        let net     = r.totals.value(for: .net)
        print("Totals → credits:", credits, "debits:", debits, "net:", net)

        // Derived sums from transactions (на случай, если totals пусты)
        let sumCredit = r.transactions.reduce(0.0) { $0 + max(0, $1.credit ?? (($1.amount ?? 0) > 0 ? ($1.amount ?? 0) : 0)) }
        let sumDebit  = r.transactions.reduce(0.0) { $0 + max(0, $1.debit  ?? (($1.amount ?? 0) < 0 ? abs($1.amount ?? 0) : 0)) }
        let sumNet    = sumCredit - sumDebit
        print("Derived from tx → credit:", sumCredit, "debit:", sumDebit, "net:", sumNet)

        // Первые 10 транзакций
        print("----- First transactions (up to 10) -----")
        for tx in r.transactions.prefix(10) {
            let d = df.string(from: tx.date)
            let c = (tx.credit != nil) ? String(tx.credit!) : "nil"
            let db = (tx.debit  != nil) ? String(tx.debit!)  : "nil"
            let a = (tx.amount != nil) ? String(tx.amount!) : "nil"
            let desc = tx.description.replacingOccurrences(of: "\n", with: " ").prefix(80)
            print("\(d) | credit=\(c) | debit=\(db) | amount=\(a) | \(desc)…")
        }
        print("=========================================\n")
    }

    static func filteredList(_ r: StatementResponse, metric: DisplayMetric) {
        func derivedCredit(_ tx: StatementResponse.Tx) -> Double {
            if let c = tx.credit { return max(0, c) }
            if let a = tx.amount, a > 0 { return a }
            return 0
        }
        func derivedDebit(_ tx: StatementResponse.Tx) -> Double {
            if let d = tx.debit { return max(0, d) }
            if let a = tx.amount, a < 0 { return abs(a) }
            return 0
        }

        let creditCount = r.transactions.filter { derivedCredit($0) > 0 }.count
        let debitCount  = r.transactions.filter { derivedDebit($0)  > 0 }.count

        print("===== FILTER DEBUG (\(metric.rawValue)) =====")
        print("credit>0 rows:", creditCount, "| debit>0 rows:", debitCount, "| total tx:", r.transactions.count)
        switch metric {
        case .credit:
            let sample = r.transactions.filter { derivedCredit($0) > 0 }.prefix(3)
            for tx in sample {
                print("CREDIT row →", tx.date, tx.credit ?? (tx.amount ?? 0), tx.description.prefix(50), "…")
            }
        case .debit:
            let sample = r.transactions.filter { derivedDebit($0) > 0 }.prefix(3)
            for tx in sample {
                print("DEBIT row →", tx.date, tx.debit ?? abs(tx.amount ?? 0), tx.description.prefix(50), "…")
            }
        case .net:
            print("NET shows all rows (no filter)")
        }
        print("======================================\n")
    }
}
#endif
