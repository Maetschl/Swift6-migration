/// Positive indicators that show Swift 6 concurrency migration progress in a module.
/// These are NOT findings — they measure what has already been adopted.
public struct MigrationIndicators: Codable, Sendable {
    /// Number of `actor` type declarations (replacement for class + lock).
    public let actorDeclarationCount: Int
    /// Number of `@MainActor` annotations on types, functions, or properties.
    public let mainActorAnnotationCount: Int
    /// Number of `async` function declarations.
    public let asyncFunctionCount: Int
    /// Number of `await` expression usages.
    public let awaitUsageCount: Int
    /// Number of `Sendable` conformances (checked, not @unchecked).
    public let sendableConformanceCount: Int

    public init(
        actorDeclarationCount: Int,
        mainActorAnnotationCount: Int,
        asyncFunctionCount: Int,
        awaitUsageCount: Int,
        sendableConformanceCount: Int
    ) {
        self.actorDeclarationCount = actorDeclarationCount
        self.mainActorAnnotationCount = mainActorAnnotationCount
        self.asyncFunctionCount = asyncFunctionCount
        self.awaitUsageCount = awaitUsageCount
        self.sendableConformanceCount = sendableConformanceCount
    }

    /// Sum of all positive indicators — a rough measure of how much has been migrated.
    public var totalAdopted: Int {
        actorDeclarationCount + mainActorAnnotationCount + asyncFunctionCount + sendableConformanceCount
    }

    /// Combines two sets of indicators by summing each field (for aggregating across a module tree).
    public static func + (lhs: MigrationIndicators, rhs: MigrationIndicators) -> MigrationIndicators {
        MigrationIndicators(
            actorDeclarationCount:    lhs.actorDeclarationCount    + rhs.actorDeclarationCount,
            mainActorAnnotationCount: lhs.mainActorAnnotationCount + rhs.mainActorAnnotationCount,
            asyncFunctionCount:       lhs.asyncFunctionCount       + rhs.asyncFunctionCount,
            awaitUsageCount:          lhs.awaitUsageCount          + rhs.awaitUsageCount,
            sendableConformanceCount: lhs.sendableConformanceCount + rhs.sendableConformanceCount
        )
    }

    public static var empty: MigrationIndicators {
        MigrationIndicators(
            actorDeclarationCount: 0,
            mainActorAnnotationCount: 0,
            asyncFunctionCount: 0,
            awaitUsageCount: 0,
            sendableConformanceCount: 0
        )
    }
}
