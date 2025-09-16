//
//  QRScannerView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 16/9/25.
//

import SwiftUI
import VisionKit
internal import Vision

struct QRScannerView: UIViewControllerRepresentable {
    var onURLDetected: (URL) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onURLDetected: onURLDetected) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private var last: String?
        let onURLDetected: (URL) -> Void
        init(onURLDetected: @escaping (URL) -> Void) { self.onURLDetected = onURLDetected }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let item = items.first, case .barcode(let b) = item, let s = b.payloadStringValue else { return }
            guard s != last else { return }
            last = s
            if let url = URL(string: s) { onURLDetected(url) }
        }
    }
}
