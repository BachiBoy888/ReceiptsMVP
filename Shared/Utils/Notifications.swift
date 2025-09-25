//
//  Notifications.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

// Shared/Utils/Notifications.swift
import Foundation

extension Notification.Name {
    /// Публикуем, когда в хранилище чеков появилась/обновилась запись
    static let receiptsDidChange = Notification.Name("receiptsDidChange")
}
