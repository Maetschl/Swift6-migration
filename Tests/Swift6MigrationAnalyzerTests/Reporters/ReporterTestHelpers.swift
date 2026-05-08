import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

// MARK: - Shared fixture builder

func makeModuleResult(
    name: String,
    findings: [Finding],
    fileCount: Int = 1,
    linesOfCode: Int = 10,
    depth: Int = 0,
    parentQualifiedName: String? = nil
) -> ModuleResult {
    let score = FindingComplexity.score(for: findings)
    let qualifiedName = parentQualifiedName.map { "\($0)/\(name)" } ?? name
    return ModuleResult(
        name: name,
        qualifiedName: qualifiedName,
        path: "/fake/\(qualifiedName)",
        status: score == 0 ? .migrated : .pendingMigration,
        score: score,
        fileCount: fileCount,
        totalLinesOfCode: linesOfCode,
        findings: findings,
        depth: depth,
        parentQualifiedName: parentQualifiedName
    )
}

func makeFinding(
    file: String = "Test.swift",
    line: Int = 1,
    severity: Severity = .warning,
    rule: String = "ForceUnwrapRule",
    message: String = "Test message"
) -> Finding {
    Finding(file: file, line: line, severity: severity, rule: rule, message: message)
}
