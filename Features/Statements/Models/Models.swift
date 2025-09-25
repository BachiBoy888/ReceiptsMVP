//  Models.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

import Foundation

struct StatementResponse: Codable {
    let meta: Meta?
    let account: Account?

    let period: Period
    let dailySpending: [Daily]
    let transactions: [Tx]
    let totals: Totals

    // НОВОЕ: серия точек по каждой операции (может отсутствовать)
    let timeline: [TimelinePoint]?

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
        let from: Date      // сервер: "yyyy-MM-dd" — наш декодер это понимает
        let to: Date
    }

    struct Daily: Codable {
        let date: Date
        let credit: Double?
        let debit: Double?
        let net: Double?
        let amount: Double?

        // НОВОЕ: кумулятив на конец дня (EOD)
        let cumulativeClose: Double?

        // удобный доступ по выбранной метрике (как было)
        func value(for metric: DisplayMetric) -> Double {
            switch metric {
            case .credit: return credit ?? 0
            case .debit:  return debit  ?? (amount ?? 0)
            case .net:    return net    ?? ((credit ?? 0) - (debit ?? (amount ?? 0)))
            }
        }
    }

    struct Tx: Codable, Identifiable {
        // СТАРОЕ: дата дня (без времени)
        let date: Date
        let description: String

        // НОВОЕ: полноценное время операции
        let ts: Date

        // НОВЫЙ контракт сумм (может быть nil, если старый сервер)
        let credit: Double?
        let debit: Double?

        // СТАРЫЙ контракт (может отсутствовать на новом сервере)
        let amount: Double?

        // Стабильный id для SwiftUI
        var id: String { "\(ts.timeIntervalSince1970)-\(description)" }

        enum CodingKeys: String, CodingKey {
            case date, description, ts, credit, debit, amount
        }

        // делаем ts обязательным, но с безопасным fallback на date
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.date = try c.decode(Date.self, forKey: .date)
            self.description = try c.decode(String.self, forKey: .description)
            self.credit = try? c.decode(Double.self, forKey: .credit)
            self.debit  = try? c.decode(Double.self, forKey: .debit)
            self.amount = try? c.decode(Double.self, forKey: .amount)

            if let tsVal = try? c.decode(Date.self, forKey: .ts) {
                self.ts = tsVal
            } else {
                // fallback: если ts не пришёл, используем date как полночь
                self.ts = self.date
            }
        }
    }

    struct TimelinePoint: Codable, Identifiable {
        let ts: Date
        let cumulative: Double
        var id: Date { ts }
    }

    struct Totals: Codable {
        let credits: Double?
        let debits: Double?
        let net: Double?
        let expenses: Double?
        let spending: Double?

        func value(for metric: DisplayMetric) -> Double {
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
    case credit = "Пополнения"
    case debit  = "Списания"
    case net    = "Сводная"
}
