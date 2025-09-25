//
//  TxAdapter.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Adapters/TxAdapter.swift
import Foundation
import CryptoKit

private func normalizeDescription(_ s: String) -> String {
    // в нижний регистр, без лишних пробелов, оставим только буквы/цифры/пробел
    let lower = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let filtered = lower.unicodeScalars.filter { CharacterSet.alphanumerics.union(.whitespaces).contains($0) }
    return String(String.UnicodeScalarView(filtered)).replacingOccurrences(of: " +", with: " ", options: .regularExpression)
}

private func tiyins(from decimal: Decimal) -> Int {
    let ns = NSDecimalNumber(decimal: decimal.magnitude)
    return Int((ns.doubleValue * 100.0).rounded())
}

private func tiyins(from double: Double) -> Int {
    Int((abs(double) * 100.0).rounded())
}

/// Стабильный UUID из (день:часы:минуты, сумма в тыйынах, нормализованный мерчант)
func stableTxUUID(_ tx: StatementResponse.Tx) -> UUID {
    let cal = Calendar(identifier: .gregorian)
    let rounded = cal.date(bySetting: .second, value: 0, of: tx.ts) ?? tx.ts
    let minuteStart = cal.date(bySetting: .nanosecond, value: 0, of: rounded) ?? rounded

    let sumTiyin: Int = {
        if let a = tx.amount { return tiyins(from: a) }
        if let d = tx.debit, d > 0 { return tiyins(from: d) }
        if let c = tx.credit, c > 0 { return tiyins(from: c) }
        return 0
    }()

    let merchant = normalizeDescription(tx.description)

    let key = "\(Int(minuteStart.timeIntervalSince1970))|\(sumTiyin)|\(merchant)"
    let digest = SHA256.hash(data: Data(key.utf8))
    let b = Array(digest.prefix(16))
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
}

func toTransaction(_ tx: StatementResponse.Tx) -> Transaction {
    let amountDouble: Double = {
        if let a = tx.amount { return a }
        let debit = tx.debit ?? 0
        let credit = tx.credit ?? 0
        if debit > 0 { return -abs(debit) }
        if credit > 0 { return abs(credit) }
        return 0
    }()
    return Transaction(
        id: stableTxUUID(tx),
        postedAt: tx.ts,
        amount: Decimal(amountDouble),
        merchant: tx.description
    )
}
