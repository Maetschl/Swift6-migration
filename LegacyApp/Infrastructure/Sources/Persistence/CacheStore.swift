import Foundation

// ❌ UncheckedSendable
final class CacheStore: @unchecked Sendable {

    // ❌ SynchronizationPrimitive
    private let lock = NSLock()
    private var store: [String: (data: Data, expiry: Date)] = [:]

    // ❌ ForceUnwrap — should use optional binding
    func get(_ key: String) -> Data {
        lock.lock()
        defer { lock.unlock() }
        return store[key]!.data // crash if key missing
    }

    func set(_ key: String, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        let expiry = Calendar.current.date(byAdding: .second, value: cacheExpirySeconds, to: Date())!
        store[key] = (data, expiry)
    }

    // ❌ ForceUnwrap
    func isExpired(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return store[key]!.expiry < Date()
    }

    // ❌ CompletionHandler
    func evictExpired(completion: @escaping (Int) -> Void) {
        DispatchQueue.global(qos: .background).async {
            self.lock.lock()
            let expired = self.store.filter { $0.value.expiry < Date() }.map { $0.key }
            expired.forEach { self.store.removeValue(forKey: $0) }
            self.lock.unlock()
            DispatchQueue.main.async {
                completion(expired.count)
            }
        }
    }
}
