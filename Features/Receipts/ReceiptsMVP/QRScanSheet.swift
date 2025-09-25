//
//  QRScanSheet.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

private enum ScanState: Equatable {
    case idle, scanning, success, error(String?)
    var borderColor: Color {
        switch self {
        case .idle, .scanning: .white
        case .success: .green
        case .error: .red
        }
    }
    var message: String {
        switch self {
        case .idle: "Наведите камеру на QR-код чека"
        case .scanning: "Сканируем…"
        case .success: "Чек найден!"
        case .error: "Это не QR с чеком. Попробуйте ещё раз."
        }
    }
}

struct QRScanSheet: View {
    /// Возвращаем в родителя URL чека + фото (если из камеры или из галереи)
    var onFound: (URL, UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: ScanState = .idle
    @State private var showHaptic = true
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            // Камера: отдаёт (url, image)
            QRScannerView { url, image in
                handleScanned(url: url, image: image)
            }
            .ignoresSafeArea()

            OverlayView(state: state).padding()
            topBar
        }
        .onAppear { state = .scanning }
        // ⚠️ Без .photosPicker(isPresented:) — только кнопка PhotosPicker + onChange
        .onChange(of: pickerItem) { _, newValue in
            guard let item = newValue else { return }
            Task { await detectQRFromPhoto(item) }
        }
    }

    // Верхняя панель: закрыть + кнопка «Галерея»
    private var topBar: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.ultraThickMaterial)
                        .symbolRenderingMode(.hierarchical)
                }
                Spacer()
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Галерея", systemImage: "photo.on.rectangle")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .labelStyle(.titleAndIcon)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            Spacer()
        }
    }

    // Проверка, что это URL чека налоговой
    private func isValidReceiptURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), host == "tax.salyk.kg" else { return false }
        return url.absoluteString.contains("/ticket")
    }

    // Единый обработчик успешного скана (камера/галерея)
    private func handleScanned(url: URL, image: UIImage?) {
        withAnimation(.easeInOut(duration: 0.2)) { state = .scanning }
        if isValidReceiptURL(url) {
            if showHaptic { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { state = .success }
            // отдаём наверх и закрываем шторку
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onFound(url, image)   // ← фото пойдёт в ReceiptStore через ContentView
                dismiss()
            }
        } else {
            if showHaptic { UINotificationFeedbackGenerator().notificationOccurred(.error) }
            withAnimation(.easeInOut(duration: 0.25)) { state = .error("Не похоже на чек налоговой") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.2)) { state = .scanning }
            }
        }
    }

    // Распознаём QR из выбранного фото
    private func detectQRFromPhoto(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { return }

            let context = CIContext()
            let ciImage: CIImage
            if let cg = uiImage.cgImage { ciImage = CIImage(cgImage: cg) }
            else { ciImage = CIImage(image: uiImage) ?? CIImage() }

            let detector = CIDetector(
                ofType: CIDetectorTypeQRCode,
                context: context,
                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
            )
            let features = detector?.features(in: ciImage) ?? []
            let messages = features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }

            if let payload = messages.first, let url = URL(string: payload), isValidReceiptURL(url) {
                handleScanned(url: url, image: uiImage) // передаём фото наверх — сохранится в базе
            } else {
                if showHaptic { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                withAnimation { state = .error("Файл не содержит QR чека") }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { state = .scanning }
                }
            }
        } catch {
            if showHaptic { UINotificationFeedbackGenerator().notificationOccurred(.error) }
            withAnimation { state = .error("Не удалось распознать изображение") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { state = .scanning }
            }
        }
    }
}

// MARK: - Overlay (рамка и подсказка)

private struct OverlayView: View {
    var state: ScanState
    private let boxSize: CGFloat = 250

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .mask(
                    HoleShape(rect: CGRect(x: 0, y: 0, width: boxSize, height: boxSize))
                        .fill(style: FillStyle(eoFill: true))
                )
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(state.borderColor, lineWidth: 3)
                .frame(width: boxSize, height: boxSize)
                .shadow(radius: state == .success ? 6 : 0)
                .animation(.easeInOut(duration: 0.2), value: state)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                Text(state.message)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
            .allowsHitTesting(false)
        }
        .compositingGroup()
    }
}

private struct HoleShape: Shape {
    var rect: CGRect
    func path(in r: CGRect) -> Path {
        var p = Path(CGRect(origin: .zero, size: r.size))
        let hole = UIBezierPath(
            roundedRect: CGRect(
                x: (r.width - rect.width)/2,
                y: (r.height - rect.height)/2,
                width: rect.width,
                height: rect.height
            ),
            cornerRadius: 14
        )
        p.addPath(Path(hole.cgPath))
        return p
    }
}
