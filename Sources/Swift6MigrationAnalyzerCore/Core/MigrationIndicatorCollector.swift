import SwiftSyntax

/// Walks a syntax tree and counts positive Swift 6 concurrency adoption indicators.
final class MigrationIndicatorCollector: SyntaxVisitor {
    var actorDeclarationCount = 0
    var mainActorAnnotationCount = 0
    var asyncFunctionCount = 0
    var awaitUsageCount = 0
    var sendableConformanceCount = 0

    override init(viewMode: SyntaxTreeViewMode = .sourceAccurate) {
        super.init(viewMode: viewMode)
    }

    // MARK: - Visitors

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        actorDeclarationCount += 1
        return .visitChildren
    }

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.attributeName.description.trimmingCharacters(in: .whitespaces)
        if name == "MainActor" {
            mainActorAnnotationCount += 1
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.signature.effectSpecifiers?.asyncSpecifier != nil {
            asyncFunctionCount += 1
        }
        return .visitChildren
    }

    override func visit(_ node: AwaitExprSyntax) -> SyntaxVisitorContinueKind {
        awaitUsageCount += 1
        return .visitChildren
    }

    override func visit(_ node: InheritedTypeSyntax) -> SyntaxVisitorContinueKind {
        let typeText = node.type.description.trimmingCharacters(in: .whitespaces)
        if typeText == "Sendable" {
            let parentDescription = node.parent?.description ?? ""
            if !parentDescription.contains("@unchecked") {
                sendableConformanceCount += 1
            }
        }
        return .visitChildren
    }

    // MARK: - Result builder

    func build() -> MigrationIndicators {
        MigrationIndicators(
            actorDeclarationCount: actorDeclarationCount,
            mainActorAnnotationCount: mainActorAnnotationCount,
            asyncFunctionCount: asyncFunctionCount,
            awaitUsageCount: awaitUsageCount,
            sendableConformanceCount: sendableConformanceCount
        )
    }

    // MARK: - Merge helper (used to combine results across multiple files)

    static func merge(
        _ a: MigrationIndicatorCollector,
        _ b: MigrationIndicatorCollector
    ) -> MigrationIndicatorCollector {
        let result = MigrationIndicatorCollector()
        result.actorDeclarationCount    = a.actorDeclarationCount    + b.actorDeclarationCount
        result.mainActorAnnotationCount = a.mainActorAnnotationCount + b.mainActorAnnotationCount
        result.asyncFunctionCount       = a.asyncFunctionCount       + b.asyncFunctionCount
        result.awaitUsageCount          = a.awaitUsageCount          + b.awaitUsageCount
        result.sendableConformanceCount = a.sendableConformanceCount + b.sendableConformanceCount
        return result
    }
}
