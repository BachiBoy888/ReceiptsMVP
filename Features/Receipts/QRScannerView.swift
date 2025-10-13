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

// MARK: - ScannerVC

final class ScannerVC: UIViewController,
                       AVCaptureMetadataOutputObjectsDelegate,
                       AVCapturePhotoCaptureDelegate {

    // MARK: Public
    var onFound: ((URL, UIImage?) -> Void)?

    // MARK: Private
    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!

    private var isProcessing = false
    private var pendingURL: URL?
    private var lastCapturedImage: UIImage?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Чтобы превью корректно растягивалось после автолэйаута
        previewLayer?.frame = view.bounds
    }

    deinit {
        if session.isRunning { session.stopRunning() }
    }

    // MARK: Camera

    private func setupCamera() {
        // Разрешение на камеру (минимальная обработка)
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }

        session.beginConfiguration()

        // Input
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            presentAlert(title: "Камера", message: "Не удалось получить доступ к камере.")
            return
        }
        session.addInput(input)

        // Outputs
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()

        // Preview
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

        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    // MARK: QR delegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !isProcessing,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let raw = obj.stringValue else { return }

        isProcessing = true

        // Нормализуем ссылку из QR (форсируем https и правильный домен)
        guard let normalized = Self.normalizeSalykURL(raw) else {
            isProcessing = false
            presentAlert(title: "QR не распознан", message: "Это не ссылка на чек Салик. Попробуйте снова.")
            return
        }

        pendingURL = normalized

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

        guard let url else {
            presentAlert(title: "Ошибка", message: "Не удалось получить ссылку из QR.")
            return
        }
        onFound?(url, image)
    }

    // MARK: Helpers

    /// Принудительно делаем https и валидируем ссылку на ticket API
    private static func normalizeSalykURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // если в QR http — меняем на https
        if s.hasPrefix("http://") { s = "https://" + s.dropFirst("http://".count) }

        guard var comps = URLComponents(string: s) else { return nil }
        comps.scheme = "https"                              // ATS-friendly
        comps.host = "tax.salyk.kg"                         // фикс домена

        // Должен быть путь вида /client/api/v1/ticket
        guard let path = comps.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              path.contains("/client/api/v1/ticket") else {
            return nil
        }
        comps.path = path

        return comps.url
    }

    private func presentAlert(title: String, message: String) {
        // Показать простое сообщение вместо “тишины”
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(ac, animated: true)
    }
}
