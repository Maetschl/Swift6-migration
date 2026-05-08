public enum MigrationStatus: String, Codable, Sendable {
    case migrated         = "Migrated"
    case pendingMigration = "Pending Migration"

    public var icon: String {
        switch self {
        case .migrated:         return "✅"
        case .pendingMigration: return "⏳"
        }
    }

    public var htmlClass: String {
        switch self {
        case .migrated:         return "migrated"
        case .pendingMigration: return "pending"
        }
    }
}
