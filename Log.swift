//
//  Log.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import Foundation
import os

enum Log {
    static let net = Logger(subsystem: "kg.tmaralov.receiptsmvp", category: "network")
    static let parse = Logger(subsystem: "kg.tmaralov.receiptsmvp", category: "parse")
    static let db = Logger(subsystem: "kg.tmaralov.receiptsmvp", category: "database")
    static let ui = Logger(subsystem: "kg.tmaralov.receiptsmvp", category: "ui")
}

extension String {
    /// Удобно резать длинные строки в лог
    func prefixLines(_ max: Int) -> String {
        let lines = self.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.prefix(max).joined(separator: "\n")
    }
}
