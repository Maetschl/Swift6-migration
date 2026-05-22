public struct XcodeReporter: Reporter {
    public init() {}

    public func generate(findings: [Finding]) -> String {
        guard !findings.isEmpty else {
            return "// swift6-analyzer: no findings"
        }

        return findings
            .sorted(by: Self.sortFindings)
            .map(Self.format)
            .joined(separator: "\n")
    }

    public func generate(modules: [ModuleResult], projectName: String) -> String {
        generate(findings: modules.flatMap(\.findings))
    }

    private static func sortFindings(_ lhs: Finding, _ rhs: Finding) -> Bool {
        if lhs.file != rhs.file { return lhs.file < rhs.file }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        if lhs.column != rhs.column { return lhs.column < rhs.column }
        return lhs.rule < rhs.rule
    }

    private static func format(_ finding: Finding) -> String {
        "\(finding.file):\(finding.line):\(finding.column): \(severityLabel(for: finding.severity)): [\(finding.rule)] \(finding.message)"
    }

    private static func severityLabel(for severity: Severity) -> String {
        switch severity {
        case .error:
            return "error"
        case .warning, .info:
            return "warning"
        }
    }
}
