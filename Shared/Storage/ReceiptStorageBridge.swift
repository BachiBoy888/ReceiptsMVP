//
//  ReceiptStorageBridge.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Storage/ReceiptStorageBridge.swift
import Foundation
import SwiftData
import CryptoKit

/// Делаем стабильный UUID из customId (или другого уникального поля)
private func uuidFromHexString(_ hex: String) -> UUID {
    let digest = SHA256.hash(data: Data(hex.utf8))
    let b = Array(digest.prefix(16))
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
}

enum ReceiptStorageBridge {
    /// Старый метод, если где-то нужен только список тикетов
    static func loadAllReceipts(context: ModelContext) throws -> [ReceiptTicket] {
        return try loadAllReceiptsWithMapping(context: context).tickets
    }

    /// Новый: возвращает тикеты и маппинг ticketId -> Receipt (для открытия экрана детали)
    static func loadAllReceiptsWithMapping(context: ModelContext) throws -> (tickets: [ReceiptTicket], byTicketId: [UUID: Receipt]) {
        let descriptor = FetchDescriptor<Receipt>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let list = try context.fetch(descriptor)

        var tickets: [ReceiptTicket] = []
        var map: [UUID: Receipt] = [:]

        for r in list {
            guard let url = URL(string: r.sourceURL) else { continue }
            let id = uuidFromHexString(r.customId)

            let ticket = ReceiptTicket(
                id: id,
                issuedAt: r.date,
                total: r.total,
                tin: r.inn,
                fn: nil, fd: nil, fm: nil,
                regNumber: nil,
                sourceURL: url
            )
            tickets.append(ticket)
            map[id] = r
        }
        return (tickets, map)
    }
}
