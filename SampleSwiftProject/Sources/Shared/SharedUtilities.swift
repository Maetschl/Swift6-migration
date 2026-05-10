import Foundation

// ✅ Fully migrated — Shared utilities using Swift 6 patterns

/// Thread-safe cache using actor isolation
actor Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]

    func get(_ key: Key) -> Value? {
        storage[key]
    }

    func set(_ key: Key, value: Value) {
        storage[key] = value
    }

    func remove(_ key: Key) {
        storage.removeValue(forKey: key)
    }

    func clear() {
        storage.removeAll()
    }
}

/// Sendable value type for passing data across actor boundaries
struct UserProfile: Sendable {
    let id: String
    let name: String
    let email: String
    let avatarURL: URL?
}

/// Async image loader — no completion handlers
struct ImageLoader {
    func load(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
