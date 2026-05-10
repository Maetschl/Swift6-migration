import Foundation

// ✅ Fully migrated — Sendable value types safe across actor boundaries

struct User: Sendable, Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let avatarURL: URL?
    let role: Role
    let createdAt: Date

    enum Role: String, Sendable, Codable {
        case admin, editor, viewer
    }
}

struct Post: Sendable, Identifiable, Codable {
    let id: String
    let authorID: String
    let title: String
    let body: String
    let tags: [String]
    let publishedAt: Date?
    let isPublished: Bool
}

struct PaginatedResponse<T: Sendable & Codable>: Sendable, Codable {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let hasNextPage: Bool
}

enum APIError: Error, Sendable {
    case unauthorized
    case notFound
    case serverError(code: Int)
    case decodingFailed
    case networkUnavailable
}
