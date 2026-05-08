import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

// MARK: - Shared fixture builder

func makeModuleResult(
    name: String,
    findings: [Finding],
    fileCount: Int = 1,
    linesOfCode: Int = 10
) -> ModuleResult {
    let score = FindingComplexity.score(for: findings)
    return ModuleResult(
        name: name,
        path: "/fake/\(name)",
        status: score == 0 ? .migrated : .pendingMigration,
        score: score,
        fileCount: fileCount,
        totalLinesOfCode: linesOfCode,
        findings: findings
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
