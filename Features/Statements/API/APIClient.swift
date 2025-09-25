//
//  APIClient.swift
//  StatementsViewer
//
//  Created by Tilek Maralov on 24/9/25.
//

// APIClient.swift
import Foundation

struct APIClient {
    static let baseURL = URL(string: "https://xls-converter.onrender.com")!
    static var apiToken: String? = "58d1ed73e3e5f35553bf39d8dc01d6dc"

    enum APIError: LocalizedError {
            case unsupportedType415
            case tooLarge413
            case parseFailed                      // 422/500 без подробностей
            case offline
            case server(code: Int, body: String?) // <— добавили тело
            case decoding(Error)
            case other(Error)

            var errorDescription: String? {
                switch self {
                case .unsupportedType415:
                    return "Поддерживается только .xls (MBank)."
                case .tooLarge413:
                    return "Файл больше 20 МБ."
                case .parseFailed:
                    return "Не удалось распарсить выписку. Проверьте формат MBank .xls."
                case .offline:
                    return "Нет соединения. Попробуйте снова."
                case .server(let code, let body):
                    // Показать код + первый кусок тела (если есть)
                    if let body, !body.isEmpty {
                        let snippet = body.count > 500 ? String(body.prefix(500)) + "…" : body
                        return "Ошибка сервера (\(code)). \(snippet)"
                    }
                    return "Ошибка сервера (\(code))."
                case .decoding:
                    return "Ошибка чтения ответа сервера."
                case .other(let e):
                    return e.localizedDescription
                }
            }
        }


    static func uploadXLS(data: Data, filename: String) async throws -> StatementResponse {
            // оффлайн
            guard NetworkMonitor.shared.isReachable else { throw APIError.offline }

            // multipart...
            let boundary = "----\(UUID().uuidString)"
            var req = URLRequest(url: baseURL.appendingPathComponent("/api/statement/parse"))
            req.httpMethod = "POST"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            if let token = apiToken { req.setValue(token, forHTTPHeaderField: "x-api-token") }

            var body = Data()
            func append(_ s: String) { body.append(s.data(using: .utf8)!) }
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
            append("Content-Type: application/vnd.ms-excel\r\n\r\n")
            body.append(data)
            append("\r\n--\(boundary)--\r\n")
            req.httpBody = body

            do {
                let (respData, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw APIError.parseFailed }

                #if DEBUG
                print("HTTP \(http.statusCode)")
                print("Response body:", String(data: respData, encoding: .utf8) ?? "nil")
                #endif

                switch http.statusCode {
                case 200:
                    do {
                        return try JSONDecoder.statement.decode(StatementResponse.self, from: respData)
                    } catch {
                        #if DEBUG
                        print("DECODING ERROR:", error)
                        #endif
                        throw APIError.decoding(error)
                    }
                case 413:
                    throw APIError.tooLarge413
                case 415:
                    throw APIError.unsupportedType415
                case 422, 500:
                    throw APIError.parseFailed
                default:
                    let bodyText = String(data: respData, encoding: .utf8)
                    throw APIError.server(code: http.statusCode, body: bodyText)
                }
            } catch let e as APIError {
                throw e
            } catch {
                throw APIError.other(error)
            }
        }
}
