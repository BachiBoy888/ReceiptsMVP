//
//  Storage.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

// StatementStorage.swift
import Foundation

enum StatementStorage {
    static private var url: URL {
        let dir = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return dir.appendingPathComponent("last_statement.json")
    }
    static func save(_ r: StatementResponse) {
        do { try JSONEncoder.statement.encode(r).write(to: url, options: .atomic) } catch { print("save error", error) }
    }
    static func load() -> StatementResponse? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do { return try JSONDecoder.statement.decode(StatementResponse.self, from: Data(contentsOf: url)) } catch { return nil }
    }
}

enum CSVBuilder {
    static func transactionsCSV(_ txs: [StatementResponse.Tx]) -> Data {
        var rows: [String] = ["date,description,amount"]
        let df = ISO8601DateFormatter()
        df.timeZone = TimeZone(identifier: "Asia/Bishkek")
        for t in txs {
            let dateStr = df.string(from: t.date)
            let desc = t.description.replacingOccurrences(of: "\"", with: "\"\"")
            rows.append("\(dateStr),\"\(desc)\",\(t.amount != nil ? "\(t.amount!)" : "")")

        }
        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }
}
