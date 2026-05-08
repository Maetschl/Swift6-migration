import Foundation

public struct MarkdownReporter: Reporter {
    public init() {}

    // MARK: - Module-aware report

    public func generate(modules: [ModuleResult], projectName: String) -> String {
        var lines: [String] = []
        let allFindings = modules.flatMap { $0.findings }
        let projectScore = modules.reduce(0.0) { $0 + $1.score }
        let projectStatus: MigrationStatus = projectScore == 0 ? .migrated : .pendingMigration
        let maxDepth = modules.map(\.depth).max() ?? 0

        lines.append("# Swift 6 Migration Report — \(projectName)")
        lines.append("")
        lines.append("Generated: \(Date().formatted())")
        lines.append("")

        // Project overview
        lines.append("## Project Overview")
        lines.append("")
        lines.append("| | |")
        lines.append("|---|---|")
        lines.append("| **Status** | \(projectStatus.icon) \(projectStatus.rawValue) |")
        lines.append("| **Migration Score** | `\(String(format: "%.2f", projectScore))` |")
        lines.append("| **Modules** | \(modules.count) |")
        lines.append("| **Max Scan Depth** | \(maxDepth) |")
        lines.append("| **Total Findings** | \(allFindings.count) |")
        lines.append("| **Total Files** | \(modules.reduce(0) { $0 + $1.fileCount }) |")
        lines.append("| **Total Lines of Code** | \(modules.reduce(0) { $0 + $1.totalLinesOfCode }) |")
        lines.append("")

        // Positive indicators summary
        let totalActors    = modules.reduce(0) { $0 + $1.migrationIndicators.actorDeclarationCount }
        let totalMainActor = modules.reduce(0) { $0 + $1.migrationIndicators.mainActorAnnotationCount }
        let totalAsync     = modules.reduce(0) { $0 + $1.migrationIndicators.asyncFunctionCount }
        let totalSendable  = modules.reduce(0) { $0 + $1.migrationIndicators.sendableConformanceCount }

        if totalActors + totalMainActor + totalAsync + totalSendable > 0 {
            lines.append("## ✅ Migration Progress Indicators")
            lines.append("")
            lines.append("| Indicator | Count |")
            lines.append("|-----------|-------|")
            lines.append("| `actor` declarations | \(totalActors) |")
            lines.append("| `@MainActor` annotations | \(totalMainActor) |")
            lines.append("| `async` functions | \(totalAsync) |")
            lines.append("| `Sendable` conformances | \(totalSendable) |")
            lines.append("")
        }

        // Module table — depth-indented qualified name
        lines.append("## Modules")
        lines.append("")
        lines.append("| Module | Status | Score | Files | Lines | Findings |")
        lines.append("|--------|--------|-------|-------|-------|----------|")
        for module in modules {
            let indent = String(repeating: "· ", count: module.depth)
            let nameDisplay = indent + "`\(module.qualifiedName)`"
            lines.append("| \(nameDisplay) | \(module.status.icon) \(module.status.rawValue) | `\(String(format: "%.2f", module.score))` | \(module.fileCount) | \(module.totalLinesOfCode) | \(module.findings.count) |")
        }
        lines.append("")

        if allFindings.isEmpty {
            lines.append("✅ No migration issues found.")
            lines.append("")
            lines.append(complexityTableSection())
            return lines.joined(separator: "\n")
        }

        // Per-module findings — header depth reflects nesting level
        for module in modules where !module.findings.isEmpty {
            let headerPrefix = String(repeating: "#", count: min(2 + module.depth, 5))
            lines.append("\(headerPrefix) \(module.status.icon) \(module.qualifiedName)")
            lines.append("")
            lines.append("**Score:** `\(String(format: "%.2f", module.score))` · **Files:** \(module.fileCount) · **Lines:** \(module.totalLinesOfCode)")
            lines.append("")

            let byRule = Dictionary(grouping: module.findings, by: \.rule)
            for ruleName in byRule.keys.sorted() {
                let ruleFindings = byRule[ruleName] ?? []
                let weight = FindingComplexity.weight(for: ruleName)
                lines.append("### \(ruleName) _(weight: \(weight))_")
                lines.append("")
                for finding in ruleFindings {
                    lines.append("- \(finding.severity.badge) `\(finding.location)` — \(finding.message)")
                }
                lines.append("")
            }
        }

        // Rule summary
        lines.append("## Summary by Rule")
        lines.append("")
        lines.append("| Rule | Weight | Findings | Score Contribution |")
        lines.append("|------|--------|----------|--------------------|")
        let byRule = Dictionary(grouping: allFindings, by: \.rule)
        for ruleName in byRule.keys.sorted() {
            let count = byRule[ruleName]?.count ?? 0
            let weight = FindingComplexity.weight(for: ruleName)
            let contribution = Double(count) * weight
            lines.append("| \(ruleName) | \(weight) | \(count) | \(String(format: "%.2f", contribution)) |")
        }
        lines.append("")

        lines.append(complexityTableSection())
        return lines.joined(separator: "\n")
    }

    // MARK: - Flat report (single-file or legacy)

    public func generate(findings: [Finding]) -> String {
        var lines: [String] = []
        lines.append("# Swift 6 Migration Report")
        lines.append("")
        lines.append("Generated: \(Date().formatted())")
        lines.append("")

        if findings.isEmpty {
            lines.append("✅ No issues found.")
            return lines.joined(separator: "\n")
        }

        lines.append("**Total findings:** \(findings.count)")
        lines.append("")

        let byRule = Dictionary(grouping: findings, by: \.rule)
        for ruleName in byRule.keys.sorted() {
            guard let ruleFindings = byRule[ruleName] else { continue }
            lines.append("## \(ruleName)")
            lines.append("")
            for finding in ruleFindings {
                lines.append("- \(finding.severity.badge) `\(finding.location)` — \(finding.message)")
            }
            lines.append("")
        }

        lines.append("## Summary")
        lines.append("")
        lines.append("| Rule | Errors | Warnings | Infos |")
        lines.append("|------|--------|----------|-------|")
        for ruleName in byRule.keys.sorted() {
            let ruleFindings = byRule[ruleName] ?? []
            let errors   = ruleFindings.filter { $0.severity == .error }.count
            let warnings = ruleFindings.filter { $0.severity == .warning }.count
            let infos    = ruleFindings.filter { $0.severity == .info }.count
            lines.append("| \(ruleName) | \(errors) | \(warnings) | \(infos) |")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Complexity table

    private func complexityTableSection() -> String {
        var lines: [String] = []
        lines.append("## Finding Complexity Weight Table")
        lines.append("")
        lines.append("Score formula: **SUM(finding × complexity weight)**")
        lines.append("")
        lines.append("| Rule | Weight | Rationale |")
        lines.append("|------|--------|-----------|")
        for entry in FindingComplexity.weightTable {
            lines.append("| \(entry.rule) | \(entry.weight) | \(entry.rationale) |")
        }
        return lines.joined(separator: "\n")
    }
}
