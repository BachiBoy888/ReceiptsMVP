//
//  Transaction.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Models/Transaction.swift
import Foundation

struct Transaction: Identifiable, Codable, Hashable {
    let id: UUID
    let postedAt: Date
    let amount: Decimal // расходы < 0
    let merchant: String?
}

extension Transaction {
    var amountTiyin: Int {
        let positive = amount >= 0 ? amount : -amount
        let ns = NSDecimalNumber(decimal: positive)
        return Int((ns.doubleValue * 100.0).rounded())
    }
}
