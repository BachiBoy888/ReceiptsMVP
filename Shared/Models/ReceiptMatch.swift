//
//  ReceiptMatch.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Models/ReceiptMatch.swift
import Foundation

enum MatchScore: String, Codable { case exact, high, weak }

struct ReceiptMatch: Codable, Hashable {
    let receiptId: UUID
    let score: MatchScore
    let timeDeltaSec: Int
    let createdAt: Date
}
