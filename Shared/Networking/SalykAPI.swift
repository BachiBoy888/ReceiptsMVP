//
//  SalykAPI.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 7/10/25.
//

import Foundation

enum SalykError: LocalizedError {
    case badQR
    case requestFailed(String)
    case notFound
    case badStatus(Int)
    case emptyData

    var errorDescription: String? {
        switch self {
        case .badQR: return "Не удалось распознать QR-ссылку."
        case .requestFailed(let m): return "Ошибка сети: \(m)"
        case .notFound: return "Чек не найден."
        case .badStatus(let code): return "Сервер вернул код \(code)."
        case .emptyData: return "Сервер вернул пустой ответ."
        }
    }
}

struct SalykAPI {

    /// Принудительно делаем https и нормализуем домен/путь
    static func normalize(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("http://") { s = "https://" + s.dropFirst("http://".count) }
        guard var comps = URLComponents(string: s) else { return nil }
        comps.scheme = "https"
        comps.host = "tax.salyk.kg"
        // Ничего не меняем в query — просто сохраняем как есть
        return comps.url
    }

    /// Быстрая проверка, что это именно ссылка на ticket
    static func isTicketURL(_ url: URL) -> Bool {
        url.host == "tax.salyk.kg" && url.path.contains("/client/api/v1/ticket")
    }

    /// Вытянуть JSON по ссылке с чеком
    static func fetchTicket(from raw: String, completion: @escaping (Result<Data, SalykError>) -> Void) {
        guard
            let url = normalize(raw),
            isTicketURL(url)
        else { completion(.failure(.badQR)); return }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error.localizedDescription)))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.requestFailed("Нет HTTP ответа")))
                return
            }
            guard (200...299).contains(http.statusCode) else {
                if http.statusCode == 404 { completion(.failure(.notFound)) }
                else { completion(.failure(.badStatus(http.statusCode))) }
                return
            }
            guard let data = data, !data.isEmpty else {
                completion(.failure(.emptyData))
                return
            }
            completion(.success(data))
        }
        task.resume()
    }

    /// Достаём сумму из query (в копейках) и конвертируем в сомы
    static func extractAmountKGS(from raw: String) -> Double? {
        guard let url = normalize(raw), let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        if let sumStr = q.first(where: { $0.name == "sum" })?.value, let pennies = Int(sumStr) {
            return Double(pennies) / 100.0
        }
        return nil
    }
}
