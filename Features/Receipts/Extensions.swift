//
//  Extensions.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import Foundation

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
