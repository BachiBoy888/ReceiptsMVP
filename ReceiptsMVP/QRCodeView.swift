//
//  QRCodeView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 17/9/25.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let string: String
    let size: CGFloat

    var body: some View {
        if let image = generateQRCode(from: string, size: size) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel("QR код чека")
        } else {
            Color.gray
                .frame(width: size, height: size)
                .overlay(
                    Text("QR недоступен")
                        .font(.caption)
                        .foregroundStyle(.white)
                )
        }
    }

    private func generateQRCode(from string: String, size: CGFloat) -> UIImage? {
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        guard let cgimg = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgimg)
    }
}
