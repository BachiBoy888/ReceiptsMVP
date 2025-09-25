//
//  ISO8601+TZ.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

// ISO8601+TZ.swift
import Foundation
extension JSONDecoder.DateDecodingStrategy {
    static var iso8601withMillisAndTZ: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
            // fallback без millis
            f.formatOptions = [.withInternetDateTime]
            if let d = f.date(from: s) { return d }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad ISO8601 date"))
        }
    }
}

extension JSONEncoder.DateEncodingStrategy {
    static var iso8601withMillisAndTZ: JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            var c = encoder.singleValueContainer()
            let f = ISO8601DateFormatter()
            f.timeZone = TimeZone(identifier: "Asia/Bishkek")
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try c.encode(f.string(from: date))
        }
    }
}
