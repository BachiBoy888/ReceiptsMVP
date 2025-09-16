//
//  ReceiptStore.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import Foundation
import SwiftData
import CryptoKit
import os      // <— ДОБАВЬ


@MainActor
final class ReceiptStore {
    let context: ModelContext
    init(_ context: ModelContext) { self.context = context }

    /// Сохраняет ParsedReceipt и возвращает созданную модель Receipt.
    @discardableResult
    func save(parsed: ParsedReceipt, sourceURL: URL) throws -> Receipt {
        // генерируем свой customId (можно хранить пустым, если поле опционально)
        let customId = sha256(sourceURL.absoluteString + parsed.date.description)

        // если total не пришёл — подстрахуемся суммой позиций
        let totalToSave: Decimal = parsed.total > 0
            ? parsed.total
            : parsed.items.reduce(0) { $0 + $1.sum }

        let itemsData = try? JSONEncoder().encode(parsed.items)
        let itemsJSON = itemsData.flatMap { String(data: $0, encoding: .utf8) }

        let model = Receipt(
            customId: customId,
            date: parsed.date,
            total: totalToSave,
            merchant: parsed.merchant,
            inn: parsed.inn,
            address: parsed.address,
            sourceURL: sourceURL.absoluteString,
            itemsJSON: itemsJSON
        )
        context.insert(model)
        try context.save()
        print("DB | saved receipt id=\(customId) merchant=\(parsed.merchant) total=\(totalToSave)")
        return model
    }

    private func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
