//
//  ReceiptDetailView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins
import SafariServices
import UIKit

struct ReceiptDetailView: View {
    let receipt: Receipt

    @Environment(\.modelContext) private var modelContext
    @State private var isRestoringQR = false
    @State private var restoreMessage: String?

    // Встроенный предпросмотр сайта налоговой
    @State private var safariItem: SafariItem?

    private let twoFrac: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    var body: some View {
        List {
            // ===== Заголовок: СНАЧАЛА Заведение, ниже Организация =====
            Section {
                // Заголовок — название заведения (из address, первая часть до запятой)
                NavigationLink {
                    MerchantHistoryView(venue: venueName(for: receipt))
                } label: {
                    HStack(spacing: 6) {
                        Text(venueName(for: receipt).isEmpty ? "Заведение" : venueName(for: receipt))
                            .font(.title2).bold()
                            .lineLimit(2)
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Организация — юрлицо ниже отдельной строкой
                NavigationLink {
                    MerchantHistoryView(merchant: receipt.merchant, inn: receipt.inn)
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Организация")
                        Spacer()
                        Text(receipt.merchant.isEmpty ? "Неизвестно" : receipt.merchant)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                    }
                }

                // Адрес
                if let address = receipt.address, !address.isEmpty {
                    HStack(alignment: .top) {
                        Text("Адрес")
                        Spacer()
                        Text(address).multilineTextAlignment(.trailing)
                    }
                }

                // Дата
                HStack {
                    Text("Дата"); Spacer()
                    Text(receipt.date.formatted(date: .long, time: .shortened))
                }

                // Итого
                HStack {
                    Text("Итого"); Spacer()
                    Text(receipt.total.doubleValue, format: twoFrac).fontWeight(.semibold)
                }
            }

            // ===== Позиции чека =====
            if let items = decodeItems(receipt), !items.isEmpty {
                Section("Позиции") {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(it.name)
                                .font(.subheadline)
                            Text("Кол-во: \(it.qty.doubleValue, format: twoFrac) · Цена: \(it.price.doubleValue, format: twoFrac) · Сумма: \(it.sum.doubleValue, format: twoFrac)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // ===== QR к чеку налоговой =====
            Section {
                if let qr = qrImage(from: receipt.sourceURL) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QR к чеку налоговой")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        // Тап по QR — открыть встроенный Safari sheet
                        Button {
                            if let url = URL(string: receipt.sourceURL) {
                                safariItem = SafariItem(url: url)
                            }
                        } label: {
                            Image(uiImage: qr)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 12) {
                            Button {
                                if let url = URL(string: receipt.sourceURL) {
                                    safariItem = SafariItem(url: url)
                                }
                            } label: {
                                Label("Открыть сайт налоговой", systemImage: "safari")
                            }

                            if receipt.photoPath != nil {
                                Button {
                                    Task { await restoreURLFromPhotoAndRefresh() }
                                } label: {
                                    if isRestoringQR {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Label("Восстановить из фото", systemImage: "arrow.clockwise")
                                    }
                                }
                                .disabled(isRestoringQR)
                            }
                        }
                        .font(.footnote)

                        if let msg = restoreMessage {
                            Text(msg).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QR недоступен")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if receipt.photoPath != nil {
                            Button {
                                Task { await restoreURLFromPhotoAndRefresh() }
                            } label: {
                                if isRestoringQR {
                                    ProgressView("Восстанавливаю…")
                                } else {
                                    Label("Восстановить ссылку из фото", systemImage: "arrow.clockwise")
                                }
                            }
                        }
                    }
                }
            }

            // ===== Фото чека (если сохранено) =====
            if let path = receipt.photoPath, let img = loadImage(path) {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Фото чека").font(.footnote).foregroundStyle(.secondary)
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .navigationTitle("Чек")
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
        }
    }

    // MARK: - Helpers

    private func decodeItems(_ r: Receipt) -> [ParsedItem]? {
        guard let json = r.itemsJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([ParsedItem].self, from: data)
    }

    /// Извлекаем «название заведения» — первую часть адреса до запятой.
    private func venueName(for r: Receipt) -> String {
        if let address = r.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let first = address.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true).first {
                let name = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
        }
        return r.merchant.isEmpty ? "Неизвестно" : r.merchant
    }

    private func qrImage(from string: String) -> UIImage? {
        guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M",   forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return nil }
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = out.transformed(by: scale)
        let ctx = CIContext()
        if let cg = ctx.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cg)
        }
        return nil
    }

    private func loadImage(_ relativePath: String) -> UIImage? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    @MainActor
    private func restoreURLFromPhotoAndRefresh() async {
        isRestoringQR = true
        defer { isRestoringQR = false }
        do {
            let store = ReceiptStore(modelContext)
            if try await store.restoreURLFromStoredPhoto(receipt) != nil {
                restoreMessage = "Ссылка восстановлена"
            } else {
                restoreMessage = "Не удалось восстановить ссылку из фото"
            }
        } catch {
            restoreMessage = "Ошибка: \(error.localizedDescription)"
        }
    }
}

// MARK: - Safari sheet wrapper

private struct SafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
