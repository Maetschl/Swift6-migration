import Foundation

// ❌ GlobalMutableState
var defaultTimeout: TimeInterval = 30.0
var maxRetryCount: Int = 3

// ❌ UncheckedSendable
final class HTTPClient: @unchecked Sendable {

    // ❌ NonisolatedUnsafe
    nonisolated(unsafe) var baseURL: String = "https://api.legacyapp.com"
    nonisolated(unsafe) var apiVersion: String = "v2"
    nonisolated(unsafe) var authToken: String = ""

    // ❌ SynchronizationPrimitive — NSLock guarding mutable state
    private let clientLock = NSLock()
    private var activeRequests: Set<String> = []
    private var requestLog: [String] = []

    // ❌ CompletionHandler
    func get(_ path: String, completion: @escaping (Result<Data, Error>) -> Void) {
        clientLock.lock()
        activeRequests.insert(path)
        requestLog.append("GET \(path)")
        clientLock.unlock()

        guard let url = URL(string: "\(baseURL)/\(apiVersion)\(path)") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = defaultTimeout
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            self?.clientLock.lock()
            self?.activeRequests.remove(path)
            self?.clientLock.unlock()

            if let error { completion(.failure(error)); return }
            completion(.success(data ?? Data()))
        }.resume()
    }

    // ❌ CompletionHandler
    func post(_ path: String, body: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/\(apiVersion)\(path)") else {
            completion(.failure(URLError(.badURL))); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err { completion(.failure(err)); return }
            completion(.success(data ?? Data()))
        }.resume()
    }
}
