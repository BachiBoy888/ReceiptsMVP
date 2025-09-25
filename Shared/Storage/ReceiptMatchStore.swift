//
//  ReceiptMatchStore.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Storage/ReceiptMatchStore.swift
import Foundation
import Combine

final class ReceiptMatchStore: ObservableObject {
    @Published private(set) var matched: [UUID: ReceiptMatch] = [:] // tx.id -> match

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("receipt_matches.json")
    }()

    init() { load() }

    func set(_ txId: UUID, match: ReceiptMatch?) {
        if let match {
            matched[txId] = match
        } else {
            matched.removeValue(forKey: txId)
        }
        save()
    }

    func get(_ txId: UUID) -> ReceiptMatch? { matched[txId] }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        if let map = try? JSONDecoder().decode([UUID: ReceiptMatch].self, from: data) {
            self.matched = map
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(matched) {
            try? data.write(to: url)
        }
    }
}
