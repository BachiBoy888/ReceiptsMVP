//
//  TransactionsListView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Features/Statements/Views/TransactionsListView.swift
import SwiftUI


struct TransactionsListView: View {
    @State private var safariItem: IdentifiedURL?

    let transactions: [Transaction]
    let receipts: [ReceiptTicket]
    @StateObject private var matchStore = ReceiptMatchStore()
    private let matcher = ReceiptMatcher()

    init(transactions: [Transaction], receipts: [ReceiptTicket]) {
        self.transactions = transactions
        self.receipts = receipts
        matcher.rebuildIndex(receipts)
    }

    var body: some View {
        List(transactions) { tx in
            let match = matchStore.get(tx.id)
            TransactionRow(tx: tx, hasReceipt: match != nil)
                .onTapGesture {
                    if let match, let r = receipts.first(where: { $0.id == match.receiptId }) {
                        safariItem = IdentifiedURL(url: r.sourceURL)
                    } else if let auto = matcher.match(tx),
                              let r = receipts.first(where: { $0.id == auto.receiptId }) {
                        matchStore.set(tx.id, match: auto)
                        safariItem = IdentifiedURL(url: r.sourceURL)
                    }
                }
                .contextMenu {
                    Button("Привязать чек…") {
                        // TODO: показать sheet ручной привязки
                    }
                    if match != nil {
                        Button("Отвязать чек", role: .destructive) { matchStore.set(tx.id, match: nil) }
                    }
                }
        }
        .sheet(item: $safariItem) { item in
            InAppBrowserView(url: item.url)
        }
    }
}
