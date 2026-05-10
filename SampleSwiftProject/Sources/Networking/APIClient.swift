import Foundation

// ⚠️ UncheckedSendable — bypasses all concurrency checks
final class APIClient: @unchecked Sendable {

    // ⚠️ NonisolatedUnsafe
    nonisolated(unsafe) var baseURL: String = "https://api.example.com"
    nonisolated(unsafe) var authToken: String = ""

    // ⚠️ SynchronizationPrimitive — NSLock instead of actor
    private let lock = NSLock()
    private var activeRequests: [String: URLSessionTask] = [:]

    // ⚠️ CompletionHandler
    func get(path: String, completion: @escaping (Result<Data, Error>) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        guard let url = URL(string: baseURL + path) else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(data ?? Data()))
            }
        }
        activeRequests[path] = task
        task.resume()
    }

    // ⚠️ CompletionHandler
    func post(path: String, body: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: baseURL + path) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(data ?? Data()))
            }
        }.resume()
    }
}
