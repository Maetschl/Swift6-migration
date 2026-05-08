import Foundation

public struct JSONReporter: Reporter {
    public init() {}

    // MARK: - Module-aware report

    public func generate(modules: [ModuleResult], projectName: String) -> String {
        struct RuleSummary: Codable {
            let rule: String
            let weight: Double
            let findingCount: Int
            let scoreContribution: Double
        }

        struct ProjectOutput: Codable {
            let projectName: String
            let generatedAt: String
            let status: MigrationStatus
            let totalScore: Double
            let totalFindings: Int
            let totalFiles: Int
            let totalLinesOfCode: Int
            let modules: [ModuleResult]
            let summaryByRule: [RuleSummary]
            let complexityWeightTable: [ComplexityEntry]
        }

        struct ComplexityEntry: Codable {
            let rule: String
            let weight: Double
            let rationale: String
        }

        let allFindings = modules.flatMap { $0.findings }
        let projectScore = modules.reduce(0.0) { $0 + $1.score }
        let projectStatus: MigrationStatus = projectScore == 0 ? .migrated : .pendingMigration

        let byRule = Dictionary(grouping: allFindings, by: \.rule)
        let ruleSummaries = byRule.keys.sorted().map { ruleName -> RuleSummary in
            let count = byRule[ruleName]?.count ?? 0
            let weight = FindingComplexity.weight(for: ruleName)
            return RuleSummary(
                rule: ruleName,
                weight: weight,
                findingCount: count,
                scoreContribution: Double(count) * weight
            )
        }

        let complexityEntries = FindingComplexity.weightTable.map {
            ComplexityEntry(rule: $0.rule, weight: $0.weight, rationale: $0.rationale)
        }

        let output = ProjectOutput(
            projectName: projectName,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            status: projectStatus,
            totalScore: projectScore,
            totalFindings: allFindings.count,
            totalFiles: modules.reduce(0) { $0 + $1.fileCount },
            totalLinesOfCode: modules.reduce(0) { $0 + $1.totalLinesOfCode },
            modules: modules,
            summaryByRule: ruleSummaries,
            complexityWeightTable: complexityEntries
        )

        return encode(output)
    }

    // MARK: - Flat report

    public func generate(findings: [Finding]) -> String {
        struct Output: Codable {
            let generatedAt: String
            let totalFindings: Int
            let findings: [Finding]
        }
        let output = Output(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            totalFindings: findings.count,
            findings: findings
        )
        return encode(output)
    }

    // MARK: - Helpers

    private func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}
