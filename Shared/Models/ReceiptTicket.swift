//
//  ReceiptTicket.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Models/ReceiptTicket.swift
import Foundation

struct ReceiptTicket: Identifiable, Codable, Hashable {
    let id: UUID
    let issuedAt: Date
    let total: Decimal // KGS, > 0
    let tin: String?
    let fn: String?
    let fd: String?
    let fm: String?
    let regNumber: String?
    let sourceURL: URL
}

extension ReceiptTicket {
    var amountTiyin: Int {
        // KGS -> тыйын (округление до ближайшего)
        let ns = NSDecimalNumber(decimal: total)
        return Int((ns.doubleValue * 100.0).rounded())
    }
}
