//
//  CurrencyFormatter.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 25/9/25.
//

import Foundation

extension NumberFormatter {
    static let kgs: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "KGS"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()
}

func formatKGS(_ value: Double) -> String {
    NumberFormatter.kgs.string(from: value as NSNumber) ?? "\(value) KGS"
}
