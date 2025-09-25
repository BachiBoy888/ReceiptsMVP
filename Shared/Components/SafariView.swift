//
//  SafariView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Components/SafariView.swift
import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
