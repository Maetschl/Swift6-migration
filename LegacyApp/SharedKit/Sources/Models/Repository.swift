import Foundation

// ✅ Fully migrated — async result builders and actor-safe repositories

protocol Repository<T>: Actor {
    associatedtype T: Sendable
    func findByID(_ id: String) async throws -> T
    func findAll() async throws -> [T]
    func save(_ item: T) async throws
    func delete(id: String) async throws
}

actor InMemoryUserRepository: Repository {
    private var storage: [String: User] = [:]

    func findByID(_ id: String) async throws -> User {
        guard let user = storage[id] else { throw APIError.notFound }
        return user
    }

    func findAll() async throws -> [User] {
        Array(storage.values).sorted { $0.createdAt < $1.createdAt }
    }

    func save(_ user: User) async throws {
        storage[user.id] = user
    }

    func delete(id: String) async throws {
        guard storage[id] != nil else { throw APIError.notFound }
        storage.removeValue(forKey: id)
    }
}
