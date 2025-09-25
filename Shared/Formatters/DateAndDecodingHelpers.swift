//
//  Date+Formatters.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

import Foundation

// 1) Декодер: ISO8601 с/без миллисекунд + "yyyy-MM-dd"
extension JSONDecoder {
    static var statement: JSONDecoder = {
        let d = JSONDecoder()

        let isoMs: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        let iso: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()
        let ymd: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "Asia/Bishkek")
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()

        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let dt = isoMs.date(from: s) { return dt }
            if let dt = iso.date(from: s)   { return dt }
            if let dt = ymd.date(from: s)   { return dt }
            throw DecodingError.dataCorruptedError(in: try dec.singleValueContainer(),
                debugDescription: "Unsupported date format: \(s)")
        }
        return d
    }()
}

// 2) Энкодер (если кэшируешь ответы)
extension JSONEncoder {
    static var statement: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601WithMillisAndTZ
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()
}

extension JSONEncoder.DateEncodingStrategy {
    static var iso8601WithMillisAndTZ: JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let s = f.string(from: date)
            var c = encoder.singleValueContainer()
            try c.encode(s)
        }
    }
}

// 3) Форматтер для экранов
extension DateFormatter {
    static let bishkekDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(identifier: "Asia/Bishkek")
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f
    }()
}
