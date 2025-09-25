//
//  DateFormatters.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 25/9/25.
//

import Foundation

extension DateFormatter {
    static let bishkekShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(identifier: "Asia/Bishkek")
        f.dateFormat = "d MMM"          // напр. 25 сент
        return f
    }()

    static let bishkekLong: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(identifier: "Asia/Bishkek")
        f.dateFormat = "d MMMM yyyy"    // напр. 25 сентября 2025
        return f
    }()
}
extension DateFormatter {
    static let bishkekTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(identifier: "Asia/Bishkek")
        f.dateFormat = "HH:mm"
        return f
    }()
}
