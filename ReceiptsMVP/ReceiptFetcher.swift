//
//  ReceiptFetcher.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import Foundation
import SwiftSoup
import os // используем ваш Log.*

/* ===========================
   Models
   =========================== */

struct ParsedItem: Codable {
    let name: String
    let price: Decimal
    let qty: Decimal
    let sum: Decimal
}

struct ParsedReceipt: Codable {
    let merchant: String
    let inn: String?
    let address: String?
    let date: Date
    let total: Decimal
    let items: [ParsedItem]
}

enum ReceiptFetchError: Error {
    case badStatus(Int)
    case decode
    case parse(String)
}

/* ===========================
   Fetcher
   =========================== */

final class ReceiptFetcher {

    /// Загружаем HTML (как «обычный браузер») и парсим в ParsedReceipt.
    func fetchAndParse(from url: URL) async throws -> ParsedReceipt {
        var req = URLRequest(url: url, timeoutInterval: 15)
        // Имитируем Safari на iPhone — некоторые сайты меняют верстку по User-Agent
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.setValue("ru-RU,ru;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")

        Log.net.info("GET \(url.absoluteString, privacy: .public)")

        let t0 = CFAbsoluteTimeGetCurrent()
        let (data, resp) = try await URLSession.shared.data(for: req)
        let t1 = CFAbsoluteTimeGetCurrent()

        guard let http = resp as? HTTPURLResponse else { throw ReceiptFetchError.decode }
        guard (200..<300).contains(http.statusCode) else {
            Log.net.error("HTTP \(http.statusCode)")
            throw ReceiptFetchError.badStatus(http.statusCode)
        }

        // Декодируем HTML (UTF-8 → cp1251 → latin1)
        guard let html = Self.decodeHTML(data) else {
            Log.net.error("decodeHTML failed")
            throw ReceiptFetchError.decode
        }

        Log.net.info("HTTP ok, bytes=\(data.count), time_ms=\(Int((t1 - t0)*1000))")
        Log.net.debug("HTML(head):\n\(html.split(separator: "\n").prefix(40).joined(separator: "\n"), privacy: .public)")

        let parsed = try parseHTML(html)

        // Лог распарсенных данных (кратко)
        Log.parse.info("merchant=\(parsed.merchant, privacy: .public), inn=\(parsed.inn ?? "-", privacy: .public)")
        Log.parse.info("date=\(parsed.date as NSDate, privacy: .public), total=\(String(describing: parsed.total), privacy: .public)")
        Log.parse.info("items_count=\(parsed.items.count)")
        if !parsed.items.isEmpty {
            let preview = parsed.items.prefix(3).map { "\($0.name) [\($0.qty) x \($0.price)] = \($0.sum)" }.joined(separator: " | ")
            Log.parse.debug("items_preview=\(preview, privacy: .public)")
        }

        // Полная структура в JSON (для копирования в консоль)
        #if DEBUG
        if let json = try? JSONEncoder.pretty.encodeToString(parsed) {
            Log.parse.debug("parsed_json:\n\(json, privacy: .public)")
        }
        #endif

        return parsed
    }

    /* ===========================
       Parsing tuned for tax.salyk.kg
       =========================== */

    private func parseHTML(_ html: String) throws -> ParsedReceipt {
        let doc = try SwiftSoup.parse(html)

        // ===== 1) Шапка (merchant / ИНН / адрес) — это div/span, не таблица =====
        // Блок заголовка по центру
        let center = try doc.select(".content .text-align-center").first()
        let headerBlocks = try center?.select(".mb-1") ?? Elements()

        // Merchant: обычно второй .mb-1 в .text-align-center
        let merchant: String = (try? headerBlocks.get(1).text()
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? "Неизвестно"

        // ИНН — строка вида "ИНН <span>....</span>"
        let inn: String? = (try? doc
            .select(".text-align-center .mb-1:matchesOwn(ИНН)")
            .first()?
            .select("span")
            .first()?
            .text()) ?? nil

        // Адрес — первый .mb-1 сразу после центра (вне .text-align-center)
        let address: String? = (try? doc
            .select(".content > .mb-1")
            .first()?
            .text()
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? nil

        // Дата/время — ищем в общем тексте по шаблону dd.MM.yyyy HH:mm:ss
        let fullText = try doc.text()
        let dateText = Self.firstMatch(in: fullText, pattern: #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2})"#)
        let date = Self.parseKyrgyzDate(dateText ?? "") ?? Date()

        // ===== 2) Таблица позиций .table: 5 колонок — № | Товар | Цена | Кол-во | Итого =====
        var items: [ParsedItem] = []
        if let table = try? doc.select("table.table").first() {
            for tr in try table.select("tr") {
                let tds = try tr.select("td")
                guard tds.count >= 5 else { continue }
                let first = try tds.get(0).text().trimmingCharacters(in: .whitespacesAndNewlines)
                // Первая колонка должна быть номером (иначе это заголовок/итоги)
                guard Int(first) != nil else { continue }

                let name  = try tds.get(1).text().trimmingCharacters(in: .whitespacesAndNewlines)
                let price = Self.decimal(from: try tds.get(2).text())
                let qty   = Self.decimal(from: try tds.get(3).text())
                let sum   = Self.decimal(from: try tds.get(4).text())

                if !name.isEmpty, sum > 0 {
                    items.append(.init(name: name, price: price, qty: qty, sum: sum))
                }
            }
        }

        // ===== 3) Итог чека: ищем несколько вариантов + подстраховка суммой позиций
        let sumItems: Decimal = items.reduce(0) { $0 + $1.sum }

        // Собираем кандидатов из разных подписй итога
        let totalPatterns = [
            #"(?i)\bИТОГ(?:О|А)?\b[^\d]{0,10}([\d\s\.,]+)"#,
            #"(?i)\bК\s*ОПЛАТЕ\b[^\d]{0,10}([\d\s\.,]+)"#,
            #"(?i)\bСУММА\s*ЧЕКА\b[^\d]{0,10}([\d\s\.,]+)"#
        ]

        var totalCandidates: [Decimal] = []
        for pat in totalPatterns {
            let matches = Self.matches(in: fullText, pattern: pat)
            for m in matches where m.count >= 2 {
                let num = Self.decimal(from: m[1])
                if num > 0 { totalCandidates.append(num) }
            }
        }

        // Берём максимум из найденных кандидатов
        let parsedMax: Decimal = totalCandidates.max() ?? 0

        // Финальное правило: берём максимум между найденным по тексту и суммой позиций
        let total: Decimal = max(parsedMax, sumItems)
        
        print("PARSE | totalCandidates=\(totalCandidates) sumItems=\(sumItems) -> total=\(total)")


        return ParsedReceipt(
            merchant: merchant,
            inn: inn,
            address: address,
            date: date,
            total: total,
            items: items
        )
    }

    /* ===========================
       Helpers
       =========================== */

    /// Попытка декодировать HTML: UTF-8 → cp1251 → latin1
    private static func decodeHTML(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8) { return s }
        // Windows-1251
        let encCP1251 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(0x0501))
        if let s = String(data: data, encoding: encCP1251) { return s }
        // Latin1
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        return nil
    }

    private static func decimal(from s: String) -> Decimal {
        // Убираем пробелы/nbsp, заменяем запятую на точку, фильтруем лишнее
        let normalized = s
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized.filter { "0123456789.".contains($0) }) ?? 0
    }

    private static func parseKyrgyzDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f.date(from: s)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        let r = try! NSRegularExpression(pattern: pattern, options: [])
        guard let m = r.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges >= 2,
              let range = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func matches(in text: String, pattern: String) -> [[String]] {
        let r = try! NSRegularExpression(pattern: pattern, options: [])
        return r.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)).map { m in
            (0..<m.numberOfRanges).compactMap { idx in
                guard let range = Range(m.range(at: idx), in: text) else { return nil }
                return String(text[range])
            }
        }
    }
}

/* ===========================
   Pretty JSON (DEBUG)
   =========================== */

extension JSONEncoder {
    /// Готовый "красивый" энкодер
    static var pretty: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let df = ISO8601DateFormatter()
        enc.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(df.string(from: date))
        }
        return enc
    }

    /// Удобно сразу получить строку JSON
    func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let data = try encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
