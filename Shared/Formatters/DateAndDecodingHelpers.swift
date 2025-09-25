//
//  Date+Formatters.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

import Foundation

// Форматтер для отображения дат в Бишкеке
extension DateFormatter {
    static let bishkekShort: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Asia/Bishkek")
        f.locale = Locale(identifier: "ru_RU")
        // Локализованный шаблон вроде "1 сент. 2025"
        f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return f
    }()
}

// Универсальный декодер для наших ответов сервера
extension JSONDecoder {
    static var statement: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)

            // 1) ISO8601 с миллисекундами
            let iso = ISO8601DateFormatter()
            iso.timeZone = TimeZone(identifier: "Asia/Bishkek")
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d1 = iso.date(from: s) { return d1 }

            // 2) ISO8601 без миллисекунд
            iso.formatOptions = [.withInternetDateTime]
            if let d2 = iso.date(from: s) { return d2 }

            // 3) Дата без времени "yyyy-MM-dd" (то, что сейчас отдаёт сервер)
            let df = DateFormatter()
            df.timeZone = TimeZone(identifier: "Asia/Bishkek")
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            if let d3 = df.date(from: s) { return d3 }

            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported date format: \(s)"
            ))
        }
        return d
    }()
}

// Универсальный энкодер для сохранения в кэш (Application Support)
extension JSONEncoder {
    static var statement: JSONEncoder = {
        let e = JSONEncoder()
        // используем стратегию из ISO8601+TZ.swift
        e.dateEncodingStrategy = .iso8601withMillisAndTZ
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()
}
