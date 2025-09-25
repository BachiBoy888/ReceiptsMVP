//
//  Models.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

// Models.swift
import Foundation

struct StatementResponse: Codable {
    // optional: сервер может их прислать или нет
    let meta: Meta?
    let account: Account?

    let period: Period
    let dailySpending: [Daily]
    let transactions: [Tx]
    let totals: Totals

    // MARK: - Nested

    struct Meta: Codable {
        let processedAt: Date
        let requestId: String
        struct FileInfo: Codable { let name: String; let size: Int }
        let file: FileInfo
        let sheet: String
        let rows: Int
        let parseMs: Int
    }

    struct Account: Codable {
        let currency: String
        let bank: String?
    }

    struct Period: Codable {
        let from: Date
        let to: Date
    }

    struct Daily: Codable {
        let date: Date
        // сервер может прислать полный набор...
        let credit: Double?
        let debit: Double?
        let net: Double?
        // ...или старый amount (обычно = debit по модулю)
        let amount: Double?

        // удобный доступ по выбранной метрике
        func value(for metric: DisplayMetric) -> Double {
            switch metric {
            case .credit: return credit ?? 0
            case .debit:  return debit  ?? (amount ?? 0)
            case .net:    return net    ?? ((credit ?? 0) - (debit ?? (amount ?? 0)))
            }
        }
    }

    struct Tx: Codable, Identifiable {
        let date: Date
        let description: String
        // новый контракт
        let credit: Double?
        let debit: Double?
        // старый контракт
        let amount: Double?

        var id: String { "\(date.timeIntervalSince1970)-\(description)" }

        func value(for metric: DisplayMetric) -> Double {
            switch metric {
            case .credit:
                if let c = credit { return c }
                if let a = amount, a > 0 { return a }
                return 0
            case .debit:
                if let d = debit { return d }
                if let a = amount, a < 0 { return abs(a) }
                return 0
            case .net:
                if let c = credit, let d = debit { return c - d }
                if let a = amount { return a }
                return (credit ?? 0) - (debit ?? 0)
            }
        }
    }

    struct Totals: Codable {
        // новый контракт
        let credits: Double?
        let debits: Double?
        let net: Double?
        let expenses: Double? // = debits
        // старый контракт
        let spending: Double?

        func value(for metric: DisplayMetric) -> Double {
            // поддерживаем оба варианта
            switch metric {
            case .credit: return credits ?? 0
            case .debit:  return debits ?? expenses ?? (spending ?? 0)
            case .net:    return net ?? ((credits ?? 0) - (debits ?? expenses ?? 0))
            }
        }
    }
}

// Метрика отображения (выбор табов)
enum DisplayMetric: String, CaseIterable, Codable {
    case credit = "Зачисления"
    case debit  = "Списания"
    case net    = "Нетто"
}
