import Foundation

// ❌ UncheckedSendable — bypasses all Swift 6 concurrency checks
final class AuthSessionManager: @unchecked Sendable {

    // ❌ NonisolatedUnsafe — suppresses data-race checking
    nonisolated(unsafe) var accessToken: String = ""
    nonisolated(unsafe) var refreshToken: String = ""
    nonisolated(unsafe) var userID: String = ""

    // ❌ SynchronizationPrimitive — NSLock instead of actor isolation
    private let sessionLock = NSLock()
    private var sessionData: [String: Any] = [:]

    // ❌ CompletionHandler — should be async/await
    func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        // ❌ DispatchQueue.global instead of structured concurrency
        DispatchQueue.global(qos: .userInitiated).async {
            // Simulate network call
            let token = "mock-token-\(email)"
            DispatchQueue.main.async {
                self.accessToken = token
                completion(.success(token))
            }
        }
    }

    // ❌ CompletionHandler
    func refreshSession(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: 0.5)
            DispatchQueue.main.async {
                self.accessToken = "refreshed-token"
                completion(true)
            }
        }
    }

    // ❌ CompletionHandler
    func logout(completion: @escaping () -> Void) {
        sessionLock.lock()
        sessionData.removeAll()
        accessToken = ""
        refreshToken = ""
        userID = ""
        sessionLock.unlock()
        DispatchQueue.main.async {
            completion()
        }
    }
}
