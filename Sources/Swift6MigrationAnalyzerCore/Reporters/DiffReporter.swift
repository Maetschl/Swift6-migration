import Foundation

public struct DiffReporter: Sendable {
    public init() {}

    public func generate(diff: BaselineDiff, projectName: String) -> String {
        var lines: [String] = []

        lines.append("# Swift 6 Migration Diff — \(projectName)")
        lines.append("")
        lines.append("Generated: \(Date().formatted())")
        lines.append("")
        lines.append("## Summary")
        lines.append("")
        lines.append("| Metric | Value |")
        lines.append("|--------|-------|")
        lines.append("| 🆕 New findings | \(diff.newFindings.count) |")
        lines.append("| ✅ Resolved findings | \(diff.resolvedFindings.count) |")
        lines.append("| 📊 Score delta | \(formattedTotalScoreDelta(diff.totalScoreDelta)) |")
        lines.append("")
        lines.append("## 🆕 New Findings (Regressions)")
        lines.append("")

        if diff.newFindings.isEmpty {
            lines.append("_No regressions — 🎉_")
        } else {
            for finding in diff.newFindings.sorted(by: Self.sortFindings) {
                lines.append("- 🔴 `\(finding.location)` — [\(finding.rule)] \(finding.message)")
            }
        }

        lines.append("")
        lines.append("## ✅ Resolved Findings")
        lines.append("")

        if diff.resolvedFindings.isEmpty {
            lines.append("_No resolved findings_")
        } else {
            for finding in diff.resolvedFindings.sorted(by: Self.sortFindings) {
                lines.append("- ~~`\(finding.location)`~~ — [\(finding.rule)] \(finding.message)")
            }
        }

        lines.append("")
        lines.append("## 📦 Score Changes by Module")
        lines.append("")

        if diff.scoreDeltas.isEmpty {
            lines.append("_No module score changes_")
        } else {
            lines.append("| Module | Score Delta |")
            lines.append("|--------|-------------|")
            for module in diff.scoreDeltas.keys.sorted() {
                if let delta = diff.scoreDeltas[module] {
                    lines.append("| \(module) | \(formattedModuleScoreDelta(delta)) |")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func sortFindings(_ lhs: Finding, _ rhs: Finding) -> Bool {
        if lhs.file != rhs.file { return lhs.file < rhs.file }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        if lhs.column != rhs.column { return lhs.column < rhs.column }
        return lhs.rule < rhs.rule
    }

    private func formattedTotalScoreDelta(_ delta: Double) -> String {
        if delta > 0 {
            return String(format: "+%.2f (regression)", delta)
        }

        if delta < 0 {
            return String(format: "%.2f (improvement)", delta)
        }

        return "0.00 (no change)"
    }

    private func formattedModuleScoreDelta(_ delta: Double) -> String {
        if delta > 0 {
            return String(format: "+%.2f 🔴", delta)
        }

        if delta < 0 {
            return String(format: "%.2f ✅", delta)
        }

        return "0.00 —"
    }
}
