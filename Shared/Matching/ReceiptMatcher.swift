//
//  ReceiptMatcher.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Matching/ReceiptMatcher.swift
import Foundation

struct ReceiptKey: Hashable { let amountTiyin: Int; let bucket: Int }

final class ReceiptMatcher {
    private(set) var index: [ReceiptKey: [ReceiptTicket]] = [:]
    private let bucketSeconds = 3600 // было 1800: расширим до 60 минут

    func rebuildIndex(_ receipts: [ReceiptTicket]) {
        index.removeAll(keepingCapacity: true)
        for r in receipts {
            let bucket = Int(r.issuedAt.timeIntervalSince1970) / bucketSeconds
            // индексируем сумму r.amountTiyin ±1
            for amt in [r.amountTiyin - 1, r.amountTiyin, r.amountTiyin + 1] {
                for b in (bucket - 1)...(bucket + 1) {
                    index[ReceiptKey(amountTiyin: amt, bucket: b), default: []].append(r)
                }
            }
        }
    }


    
    func match(_ tx: Transaction, merchantsMap: [String: Set<String>] = [:]) -> ReceiptMatch? {
        let bucket = Int(tx.postedAt.timeIntervalSince1970) / bucketSeconds
        var candidates: [ReceiptTicket] = []
        for b in (bucket - 1)...(bucket + 1) {
            candidates += index[ReceiptKey(amountTiyin: tx.amountTiyin, bucket: b)] ?? []
        }
        guard !candidates.isEmpty else { return nil }

        let chosen = candidates.min { a, b in
            abs(a.issuedAt.timeIntervalSince(tx.postedAt)) < abs(b.issuedAt.timeIntervalSince(tx.postedAt))
        }!
        let delta = abs(Int(chosen.issuedAt.timeIntervalSince(tx.postedAt)))

        var score: MatchScore = candidates.count == 1 ? .exact : .high
        if let m = tx.merchant?.lowercased(), let aliases = merchantsMap[m] {
            let hay = [chosen.tin, chosen.regNumber, chosen.sourceURL.host].compactMap { $0?.lowercased() }
            if hay.contains(where: { aliases.contains($0) }) { score = .exact }
        }
        return ReceiptMatch(
            receiptId: chosen.id,
            score: score,
            timeDeltaSec: delta,
            createdAt: Date()
        )
    }
}
