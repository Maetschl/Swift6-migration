// MARK: - Tag

/// An individual migration classification tag.
///
/// Tags are combined into a `MigrationStatus` set. A module may carry more than
/// one tag simultaneously (e.g. `.migrated` + `.warnings`).
public enum MigrationTag: String, Codable, Sendable, CaseIterable {
    /// The module has no Swift 6 compilation errors and no warnings.
    case migrated         = "Migrated"
    /// The module has at least one Swift 6 **compilation error** that blocks migration.
    case pendingMigration = "Pending Migration"
    /// The module has at least one `.warning`/`.info` finding (non-blocking recommendations).
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
///
/// The score used to determine `.pendingMigration` vs `.migrated` is derived **exclusively**
/// from `.error`-severity findings via `FindingComplexity.errorScore(for:)`.
/// `.warning` and `.info` findings never contribute to the score and never block migration status.
public struct MigrationStatus: Codable, Sendable, Equatable, Hashable {

    /// The set of active classification tags for this module.
    public let tags: Set<MigrationTag>

    /// Creates a `MigrationStatus` from an explicit set of tags.
    public init(_ tags: Set<MigrationTag>) {
        self.tags = tags
    }

    // MARK: - Static convenience factories

    /// Convenience status representing a fully migrated module with no issues.
    public static let migrated         = MigrationStatus([.migrated])
    /// Convenience status representing a module with unresolved Swift 6 compilation errors.
    public static let pendingMigration = MigrationStatus([.pendingMigration])

    // MARK: - Query helpers

    /// `true` when the module has at least one Swift 6 compilation error.
    public var isPendingMigration: Bool { tags.contains(.pendingMigration) }
    /// `true` when the module has **no** Swift 6 compilation errors (score == 0).
    /// Note: a migrated module may still carry the `.warnings` tag.
    public var isMigrated: Bool         { !isPendingMigration }
    /// `true` when the module has at least one `.warning` or `.info` finding.
    public var hasWarnings: Bool        { tags.contains(.warnings) }

    // MARK: - Display

    /// Human-readable label, e.g. "Migrated · Warnings" or "Pending Migration".
    public var rawValue: String {
        tags.sorted { $0.sortOrder < $1.sortOrder }.map(\.rawValue).joined(separator: " · ")
    }

    /// The emoji icon representing the dominant status.
    /// - `⏳` for pending migration, `⚠️` for migrated-with-warnings, `✅` for fully migrated.
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
