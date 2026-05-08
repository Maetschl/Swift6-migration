public struct ModuleResult: Codable, Sendable {
    /// Name of the module or target (derived from directory name).
    public let name: String
    /// Absolute path to the module root directory.
    public let path: String
    /// Overall migration status for this module.
    public let status: MigrationStatus
    /// Migration score: SUM(finding × complexity weight). 0.0 = fully migrated.
    public let score: Double
    /// Number of Swift source files analyzed in this module.
    public let fileCount: Int
    /// Total non-empty lines of code across all source files.
    public let totalLinesOfCode: Int
    /// All findings detected in this module.
    public let findings: [Finding]
    /// Positive Swift 6 concurrency adoption indicators (actors, @MainActor, async/await, Sendable).
    public let migrationIndicators: MigrationIndicators

    public init(
        name: String,
        path: String,
        status: MigrationStatus,
        score: Double,
        fileCount: Int,
        totalLinesOfCode: Int,
        findings: [Finding],
        migrationIndicators: MigrationIndicators = .empty
    ) {
        self.name = name
        self.path = path
        self.status = status
        self.score = score
        self.fileCount = fileCount
        self.totalLinesOfCode = totalLinesOfCode
        self.findings = findings
        self.migrationIndicators = migrationIndicators
    }
}
