//
//  Receipt.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import Foundation
import SwiftData

@Model
final class Receipt {
    @Attribute(.unique) var customId: String
    var date: Date
    var total: Decimal
    var merchant: String
    var inn: String?
    var address: String?
    var sourceURL: String
    var itemsJSON: String?
    var photoPath: String?   // ← НОВОЕ

    init(
        customId: String,
        date: Date,
        total: Decimal,
        merchant: String,
        inn: String?,
        address: String?,
        sourceURL: String,
        itemsJSON: String?,
        photoPath: String? = nil   // ← по умолчанию nil
    ) {
        self.customId = customId
        self.date = date
        self.total = total
        self.merchant = merchant
        self.inn = inn
        self.address = address
        self.sourceURL = sourceURL
        self.itemsJSON = itemsJSON
        self.photoPath = photoPath
    }
}
