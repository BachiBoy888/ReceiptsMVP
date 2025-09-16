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
    // Убираем : Identifiable и @Attribute(.unique)
    // Если хочешь, можем оставить свой id как строку, но без unique-атрибута.
    var customId: String           // твой хэш, просто строка
    var date: Date
    var total: Decimal
    var merchant: String
    var inn: String?
    var address: String?
    var sourceURL: String
    var itemsJSON: String?

    init(customId: String, date: Date, total: Decimal, merchant: String,
         inn: String?, address: String?, sourceURL: String, itemsJSON: String?) {
        self.customId = customId
        self.date = date
        self.total = total
        self.merchant = merchant
        self.inn = inn
        self.address = address
        self.sourceURL = sourceURL
        self.itemsJSON = itemsJSON
    }
}
