//
//  TransactionRow.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Features/Statements/Views/TransactionRow.swift
import SwiftUI

struct TransactionRow: View {
    let tx: Transaction
    let hasReceipt: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Rectangle()
                .frame(width: 4)
                .foregroundStyle(hasReceipt ? .green : .clear)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(timeString(tx.postedAt))
                        .font(.subheadline)
                        .monospacedDigit()

                    if hasReceipt {
                        Label("Чек", systemImage: "doc.text")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()
                    Text(amountString(tx.amount))
                        .font(.headline)
                }

                if let m = tx.merchant {
                    Text(m)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private func amountString(_ d: Decimal) -> String {
        let ns = NSDecimalNumber(decimal: d)
        let sign = d.sign == .minus ? "−" : "+"
        let absVal = abs(ns.doubleValue)
        return String(format: "%@%.2f KGS", sign, absVal)
    }
}
