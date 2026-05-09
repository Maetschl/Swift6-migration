// MARK: - Tag

/// An individual migration classification tag.
public enum MigrationTag: String, Codable, Sendable, CaseIterable {
    case migrated         = "Migrated"
    case pendingMigration = "Pending Migration"
    case warnings         = "Warnings"

    var sortOrder: Int {
        switch self {
        case .pendingMigration: return 0
        case .migrated:         return 1
        case .warnings:         return 2
        }
    }
}

// MARK: - Status

/// A module's migration classification — a combination of one or more `MigrationTag`s.
///
/// Possible combinations:
/// - `[.migrated]`                      — No issues at all.
/// - `[.migrated, .warnings]`           — Only non-mandatory warnings / recommendations.
/// - `[.pendingMigration]`              — Has Swift 6 compilation errors; no warnings.
/// - `[.pendingMigration, .warnings]`   — Has both errors and warnings.
public struct MigrationStatus: Codable, Sendable, Equatable, Hashable {

    public let tags: Set<MigrationTag>

    public init(_ tags: Set<MigrationTag>) {
        self.tags = tags
    }

    // MARK: - Static convenience factories

    public static let migrated         = MigrationStatus([.migrated])
    public static let pendingMigration = MigrationStatus([.pendingMigration])

    // MARK: - Query helpers

    public var isPendingMigration: Bool { tags.contains(.pendingMigration) }
    public var isMigrated: Bool         { !isPendingMigration }
    public var hasWarnings: Bool        { tags.contains(.warnings) }

    // MARK: - Display

    /// Human-readable label, e.g. "Migrated · Warnings" or "Pending Migration".
    public var rawValue: String {
        tags.sorted { $0.sortOrder < $1.sortOrder }.map(\.rawValue).joined(separator: " · ")
    }

    public var icon: String {
        if isPendingMigration { return "⏳" }
        if hasWarnings        { return "⚠️" }
        return "✅"
    }

    /// CSS class name for the primary tag (used where a single class is needed).
    public var htmlClass: String {
        if isPendingMigration { return "pending" }
        if hasWarnings        { return "tag-warnings" }
        return "migrated"
    }

    // MARK: - Multi-badge rendering

    private static let tagMeta: [(tag: MigrationTag, css: String, icon: String)] = [
        (.pendingMigration, "pending",      "⏳"),
        (.migrated,         "migrated",     "✅"),
        (.warnings,         "tag-warnings", "⚠️"),
    ]

    /// One `<span class="status-badge …">` per active tag, joined by a space.
    public var badgesHTML: String {
        Self.tagMeta
            .filter { tags.contains($0.tag) }
            .map { "<span class=\"status-badge \($0.css)\">\($0.icon) \($0.tag.rawValue)</span>" }
            .joined(separator: " ")
    }

    /// One `icon label` token per active tag, separated by two spaces (inline Markdown).
    public var badgesMarkdown: String {
        Self.tagMeta
            .filter { tags.contains($0.tag) }
            .map { "\($0.icon) \($0.tag.rawValue)" }
            .joined(separator: "  ")
    }

    // MARK: - Codable (serialised as a sorted array of tag raw values)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let strings   = try container.decode([String].self)
        self.tags     = Set(strings.compactMap(MigrationTag.init(rawValue:)))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(tags.sorted { $0.sortOrder < $1.sortOrder }.map(\.rawValue))
    }
}
