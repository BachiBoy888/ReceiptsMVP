//
//  ReceiptStore.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import Foundation
import SwiftData
import CryptoKit
import UIKit
import CoreImage

@MainActor
final class ReceiptStore {
    let context: ModelContext
    init(_ context: ModelContext) { self.context = context }

    /// Upsert + привязка фото (если передано)
    @discardableResult
    func saveOrUpdate(parsed: ParsedReceipt, sourceURL: URL, photo: UIImage?) throws -> (Receipt, Bool) {
        let customId = makeStableId(from: sourceURL, parsed: parsed)

        if let existing = try fetchByCustomId(customId) {
            var changed = false

            if existing.merchant != parsed.merchant { existing.merchant = parsed.merchant; changed = true }
            if existing.inn != parsed.inn { existing.inn = parsed.inn; changed = true }
            if existing.address != parsed.address { existing.address = parsed.address; changed = true }

            let newTotal = parsed.total > 0 ? parsed.total : parsed.items.reduce(0) { $0 + $1.sum }
            if existing.total != newTotal { existing.total = newTotal; changed = true }

            let itemsData = try? JSONEncoder().encode(parsed.items)
            let itemsJSON = itemsData.flatMap { String(data: $0, encoding: .utf8) }
            if existing.itemsJSON != itemsJSON { existing.itemsJSON = itemsJSON; changed = true }

            let originalURL = sourceURL.absoluteString
            if existing.sourceURL != originalURL { existing.sourceURL = originalURL; changed = true }

            if let photo, existing.photoPath == nil, let path = try savePhoto(photo, suggestedName: customId) {
                existing.photoPath = path
                changed = true
            }
            // ... внутри saveOrUpdate(parsed:sourceURL:photo:)
            if changed {
                try context.save()
                NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
            }
            return (existing, false)
        }

        // создаём новый
        let totalToSave: Decimal = parsed.total > 0 ? parsed.total : parsed.items.reduce(0) { $0 + $1.sum }
        let itemsData = try? JSONEncoder().encode(parsed.items)
        let itemsJSON = itemsData.flatMap { String(data: $0, encoding: .utf8) }

        var photoPath: String?
        if let photo {
            photoPath = try savePhoto(photo, suggestedName: customId)
        }

        let model = Receipt(
            customId: customId,
            date: parsed.date,
            total: totalToSave,
            merchant: parsed.merchant,
            inn: parsed.inn,
            address: parsed.address,
            sourceURL: sourceURL.absoluteString,   // ОРИГИНАЛ
            itemsJSON: itemsJSON,
            photoPath: photoPath
        )
        // ... при создании нового:
        context.insert(model)
        try context.save()
        NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
        return (model, true)
    }

    /// Попытка восстановить ссылку из сохранённого фото
    func restoreURLFromStoredPhoto(_ receipt: Receipt) async throws -> URL? {
        guard let path = receipt.photoPath,
              let image = loadImage(at: path) else { return nil }

        let ciContext = CIContext()
        let ciImage: CIImage
        if let cg = image.cgImage {
            ciImage = CIImage(cgImage: cg)
        } else {
            ciImage = CIImage(image: image) ?? CIImage()
        }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: ciContext,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) ?? []
        let messages = features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }

        if let payload = messages.first,
           let url = URL(string: payload),
           let host = url.host?.lowercased(),
           host == "tax.salyk.kg",
           url.absoluteString.contains("/ticket")
        {
            receipt.sourceURL = url.absoluteString
            try context.save()             // ← сохраняем в SwiftData, НЕ в CIContext
            NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
            return url
        }
        return nil
    }

    // MARK: - Helpers

    private func fetchByCustomId(_ id: String) throws -> Receipt? {
        let descriptor = FetchDescriptor<Receipt>(predicate: #Predicate { $0.customId == id })
        return try context.fetch(descriptor).first
    }

    private func makeStableId(from url: URL, parsed: ParsedReceipt) -> String {
        let qp = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func val(_ name: String) -> String? { qp.first(where: { $0.name.lowercased() == name })?.value }

        if let fd = val("fd_number"), let fn = val("fn_number"), let fm = val("fm") {
            return sha256("fd=\(fd)&fn=\(fn)&fm=\(fm)")
        }
        return sha256(url.absoluteString)
    }

    private func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Фото: сохранить / загрузить

    private func savePhoto(_ image: UIImage, suggestedName: String) throws -> String? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let dir = try photosDirectoryURL()
        let fileURL = dir.appendingPathComponent("\(suggestedName).jpg")
        try data.write(to: fileURL, options: .atomic)
        return "Photos/\(suggestedName).jpg"   // относительный путь
    }

    private func loadImage(at relativePath: String) -> UIImage? {
        let base = appSupportURL()
        let url = base.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func photosDirectoryURL() throws -> URL {
        let base = appSupportURL()
        let dir = base.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func appSupportURL() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base = urls[0]
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }
}
