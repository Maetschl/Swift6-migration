import Foundation

public struct MarkdownReporter: Reporter {
    public init() {}

    // MARK: - Module-aware report

    public func generate(modules: [ModuleResult], projectName: String) -> String {
        var lines: [String] = []
        let allFindings  = modules.flatMap { $0.findings }
        let projectScore = modules.filter { $0.depth == 0 }.reduce(0.0) { $0 + $1.aggregateScore }
        let hasProjectWarnings = allFindings.contains { $0.severity == .warning || $0.severity == .info }
        let projectStatus: MigrationStatus = {
            var tags: Set<MigrationTag> = projectScore == 0 ? [.migrated] : [.pendingMigration]
            if hasProjectWarnings { tags.insert(.warnings) }
            return MigrationStatus(tags)
        }()
        let migratedCount = modules.filter { $0.aggregateStatus.isMigrated }.count
        let migratedPct   = modules.isEmpty ? 0
            : Int((Double(migratedCount) / Double(modules.count) * 100).rounded())
        let maxDepthFound = modules.map(\.depth).max() ?? 0

        lines.append("# Swift 6 Migration Report — \(projectName)")
        lines.append("")
        lines.append("Generated: \(Date().formatted())")
        lines.append("")

        // ── Project overview ──────────────────────────────────────────────────
        lines.append("## Project Overview")
        lines.append("")
        lines.append("| | |")
        lines.append("|---|---|")
        lines.append("| **Status** | \(projectStatus.badgesMarkdown) |")
        lines.append("| **Subtree Score** | `\(String(format: "%.2f", projectScore))` |")
        lines.append("| **Modules Migrated** | \(migratedCount) / \(modules.count) (\(migratedPct)%) |")
        lines.append("| **Modules** | \(modules.count) |")
        lines.append("| **Max Scan Depth** | \(maxDepthFound) |")
        lines.append("| **Total Findings** | \(allFindings.count) |")
        lines.append("| **Total Files** | \(modules.reduce(0) { $0 + $1.fileCount }) |")
        lines.append("| **Total Lines of Code** | \(modules.reduce(0) { $0 + $1.totalLinesOfCode }) |")
        lines.append("")

        // ── Migration progress indicators ─────────────────────────────────────
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

        // ── Module overview table ─────────────────────────────────────────────
        // Shows qualified name, depth, aggregate status & score so container
        // modules correctly reflect their subtree's migration health.
        lines.append("## Modules")
        lines.append("")
        lines.append("| Module | Depth | Status | Own Score | Subtree Score | Files | Lines | Findings |")
        lines.append("|--------|-------|--------|-----------|---------------|-------|-------|----------|")
        for module in modules {
            let depthPrefix = module.depth > 0
                ? String(repeating: "  ", count: module.depth) + "└ "
                : ""
            let nameCell   = "\(depthPrefix)`\(module.name)`"
            let ownScore   = String(format: "%.2f", module.score)
            let aggrScore  = String(format: "%.2f", module.aggregateScore)
            let statusCell = module.aggregateStatus.badgesMarkdown
            lines.append("| \(nameCell) | \(module.depth) | \(statusCell) | `\(ownScore)` | `\(aggrScore)` | \(module.fileCount) | \(module.totalLinesOfCode) | \(module.findings.count) |")
        }
        lines.append("")

        if allFindings.isEmpty {
            lines.append("✅ No migration issues found.")
            lines.append("")
            lines.append(complexityTableSection())
            return lines.joined(separator: "\n")
        }

        // ── Per-module findings (all modules, grouped hierarchically) ─────────
        // Every module appears as a section — containers even when they have no
        // own findings — so the hierarchy is always visible in the report.
        lines.append("## Findings")
        lines.append("")

        // Build a lookup of children for grouping
        var childrenOf: [String: [ModuleResult]] = [:]
        for module in modules {
            if let parent = module.parentQualifiedName {
                childrenOf[parent, default: []].append(module)
            }
        }

        // Emit only top-level modules here; children are emitted recursively
        let topLevel = modules.filter { $0.parentQualifiedName == nil }
        for module in topLevel {
            lines.append(contentsOf: moduleSection(module, allModules: modules, childrenOf: childrenOf))
        }

        // ── Summary by rule ───────────────────────────────────────────────────
        lines.append("## Summary by Rule")
        lines.append("")
        lines.append("| Rule | Weight | Findings | Score Contribution |")
        lines.append("|------|--------|----------|--------------------|")
        let byRule = Dictionary(grouping: allFindings, by: \.rule)
        for ruleName in byRule.keys.sorted() {
            let count  = byRule[ruleName]?.count ?? 0
            let weight = FindingComplexity.weight(for: ruleName)
            lines.append("| \(ruleName) | \(weight) | \(count) | \(String(format: "%.2f", Double(count) * weight)) |")
        }
        lines.append("")

        lines.append(complexityTableSection())
        return lines.joined(separator: "\n")
    }

    // MARK: - Recursive module section builder

    private func moduleSection(
        _ module: ModuleResult,
        allModules: [ModuleResult],
        childrenOf: [String: [ModuleResult]]
    ) -> [String] {
        var lines: [String] = []
        let children = childrenOf[module.qualifiedName] ?? []
        let hasOwnFindings     = !module.findings.isEmpty
        let hasSubtreeFindings = module.aggregateScore > 0

        // Only emit a section if this module or any descendant has findings
        guard hasSubtreeFindings else { return [] }

        // Section heading — fixed ## for top-level, ### for depth 1, #### for depth 2+
        let heading = String(repeating: "#", count: min(2 + module.depth, 5))
        lines.append("\(heading) \(module.aggregateStatus.icon) \(module.qualifiedName)")
        lines.append("")

        // Meta line
        var meta = "**Own Score:** `\(String(format: "%.2f", module.score))`"
        if module.aggregateScore != module.score {
            meta += " · **Subtree Score:** `\(String(format: "%.2f", module.aggregateScore))`"
        }
        meta += " · **Files:** \(module.fileCount)"
        if !children.isEmpty {
            meta += " · **Sub-modules:** \(children.count)"
        }
        lines.append(meta)
        lines.append("")

        // Own findings grouped by rule
        if hasOwnFindings {
            let byRule = Dictionary(grouping: module.findings, by: \.rule)
            for ruleName in byRule.keys.sorted() {
                let ruleFindings = byRule[ruleName] ?? []
                let weight = FindingComplexity.weight(for: ruleName)
                // Rule heading always one level below the module heading, capped at #####
                let ruleHeading = String(repeating: "#", count: min(3 + module.depth, 6))
                lines.append("\(ruleHeading) \(ruleName) _(weight: \(weight))_")
                lines.append("")
                for finding in ruleFindings {
                    var entry = "- \(finding.severity.badge) `\(finding.location)` — \(finding.message)"
                    if let fix = finding.fix {
                        entry += "\n  > 💡 **Fix:** \(fix)"
                    }
                    lines.append(entry)
                }
                lines.append("")
            }
        } else if !children.isEmpty {
            lines.append("_No findings in this module directly — see sub-modules below._")
            lines.append("")
        }

        // Recurse into children
        for child in children {
            lines.append(contentsOf: moduleSection(child, allModules: allModules, childrenOf: childrenOf))
        }

        return lines
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
            for finding in ruleFindings { lines.append("- \(finding.severity.badge) `\(finding.location)` — \(finding.message)") }
            lines.append("")
        }

        lines.append("## Summary")
        lines.append("")
        lines.append("| Rule | Errors | Warnings | Infos |")
        lines.append("|------|--------|----------|-------|")
        for ruleName in byRule.keys.sorted() {
            let rf = byRule[ruleName] ?? []
            lines.append("| \(ruleName) | \(rf.filter { $0.severity == .error }.count) | \(rf.filter { $0.severity == .warning }.count) | \(rf.filter { $0.severity == .info }.count) |")
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
