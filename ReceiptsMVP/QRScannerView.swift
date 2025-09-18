//
//  QRScannerView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 16/9/25.
//

import SwiftUI
import AVFoundation
import UIKit

struct QRScannerView: UIViewControllerRepresentable {
    let onFound: (URL, UIImage?) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onFound = onFound
        return vc
    }
    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
}

final class ScannerVC: UIViewController,
                       AVCaptureMetadataOutputObjectsDelegate,
                       AVCapturePhotoCaptureDelegate {

    var onFound: ((URL, UIImage?) -> Void)?

    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!

    private var isProcessing = false
    private var pendingURL: URL?
    private var lastCapturedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        // Разрешение на камеру (минимальная обработка)
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }

        // 1) Начало конфигурации
        session.beginConfiguration()

        // 2) Input
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // 3) Outputs
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // 4) Завершение конфигурации ДО startRunning
        session.commitConfiguration()

        // 5) Превью-слой
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer
        } else {
            previewLayer.session = session
            previewLayer.frame = view.bounds
        }

        // 6) Запуск уже после commitConfiguration
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    // Детект QR
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !isProcessing,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let str = obj.stringValue,
              let url = URL(string: str) else { return }

        isProcessing = true
        pendingURL = url

        // Снимем кадр, затем вернём URL + фото
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // Фото получили (данные кадра)
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let data = photo.fileDataRepresentation() {
            lastCapturedImage = UIImage(data: data)
        }
    }

    // Съёмка завершена — отдаём результат
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        session.stopRunning()
        let image = lastCapturedImage
        let url = pendingURL
        pendingURL = nil
        lastCapturedImage = nil
        isProcessing = false
        if let url { onFound?(url, image) }
    }

    deinit {
        if session.isRunning { session.stopRunning() }
    }
}
