public struct ModuleResult: Codable, Sendable {
    /// Short name derived from directory name (e.g. "Core").
    public let name: String
    /// Full qualified path relative to project root (e.g. "FeatureA/Networking/Core").
    public let qualifiedName: String
    /// Absolute path to the module root directory.
    public let path: String
    /// Migration status based on this module's **own** findings only.
    public let status: MigrationStatus
    /// Migration status including all descendant modules (pending if any descendant is pending).
    public let aggregateStatus: MigrationStatus
    /// Own migration score: SUM(finding × complexity weight) for direct findings only.
    public let score: Double
    /// Subtree score: own score + sum of all descendant scores.
    public let aggregateScore: Double
    /// Number of Swift source files owned exclusively by this module.
    public let fileCount: Int
    /// Total non-empty lines of code across this module's exclusive source files.
    public let totalLinesOfCode: Int
    /// Findings detected in this module's exclusive source files.
    public let findings: [Finding]
    /// Positive Swift 6 concurrency adoption indicators.
    public let migrationIndicators: MigrationIndicators
    /// Nesting depth (0 = top-level module).
    public let depth: Int
    /// Qualified name of the direct parent module, nil for top-level modules.
    public let parentQualifiedName: String?
    /// Qualified names of direct child modules (one level below this module).
    public let childQualifiedNames: [String]
    /// Total finding count across this module and all descendants.
    public let aggregateFindings: Int
    /// Sum of all migration indicators across this module and all descendants.
    public let aggregateMigrationIndicators: MigrationIndicators
    /// Total Swift source files across this module and all descendants.
    public let aggregateFileCount: Int
    /// Total lines of code across this module and all descendants.
    public let aggregateLinesOfCode: Int

    public init(
        name: String,
        qualifiedName: String,
        path: String,
        status: MigrationStatus,
        aggregateStatus: MigrationStatus,
        score: Double,
        aggregateScore: Double,
        fileCount: Int,
        totalLinesOfCode: Int,
        findings: [Finding],
        migrationIndicators: MigrationIndicators = .empty,
        depth: Int = 0,
        parentQualifiedName: String? = nil,
        childQualifiedNames: [String] = [],
        aggregateFindings: Int? = nil,
        aggregateMigrationIndicators: MigrationIndicators? = nil,
        aggregateFileCount: Int? = nil,
        aggregateLinesOfCode: Int? = nil
    ) {
        self.name = name
        self.qualifiedName = qualifiedName
        self.path = path
        self.status = status
        self.aggregateStatus = aggregateStatus
        self.score = score
        self.aggregateScore = aggregateScore
        self.fileCount = fileCount
        self.totalLinesOfCode = totalLinesOfCode
        self.findings = findings
        self.migrationIndicators = migrationIndicators
        self.depth = depth
        self.parentQualifiedName = parentQualifiedName
        self.childQualifiedNames = childQualifiedNames
        self.aggregateFindings = aggregateFindings ?? findings.count
        self.aggregateMigrationIndicators = aggregateMigrationIndicators ?? migrationIndicators
        self.aggregateFileCount = aggregateFileCount ?? fileCount
        self.aggregateLinesOfCode = aggregateLinesOfCode ?? totalLinesOfCode
    }
}
