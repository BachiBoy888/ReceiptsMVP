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

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {
    var onFound: ((URL, UIImage?) -> Void)?

    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var isProcessing = false
    private var lastCapturedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        // Разрешение на камеру (по-хорошему, обработать .denied/.restricted в UI)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        default:
            break
        }

        // 1) Начинаем конфигурацию
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

        // 4) Завершаем конфигурацию ДО startRunning()
        session.commitConfiguration()

        // 5) Превью-слой — на главном потоке
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

        // 6) Запускаем сессию уже после commitConfiguration
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
              let url = URL(string: str)
        else { return }

        isProcessing = true

        // Сначала делаем фото, потом возвращаем URL + фото
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)

        // Запомним URL и вернёмся к нему в delegate
        pendingURL = url
    }

    private var pendingURL: URL?

    // Получили фото
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let data = photo.fileDataRepresentation() {
            lastCapturedImage = UIImage(data: data)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        session.stopRunning()
        defer { isProcessing = false }

        let image = lastCapturedImage
        let url = pendingURL
        pendingURL = nil
        lastCapturedImage = nil

        if let url { onFound?(url, image) }
    }
    
    deinit {
            if session.isRunning {
                session.stopRunning()
            }
        }
}
