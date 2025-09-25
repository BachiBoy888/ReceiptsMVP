//
//  ShareSheet+Network.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

// ShareSheet+Network.swift (исправлено)
import SwiftUI
import Network
import UIKit

// MARK: - NetworkMonitor
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private var reachable = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] p in
            self?.reachable = (p.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "nw.monitor"))
    }

    var isReachable: Bool { reachable }
}

// MARK: - ShareSheet
func presentShare(urls: [URL]) {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.keyWindow?.rootViewController else { return }
    let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
    root.present(vc, animated: true)
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
