import Foundation

/// Generates a structured JSON report designed to be fed directly to an AI coding agent.
///
/// Each finding block contains:
/// - The file path (project-relative), line, rule, severity, and message
/// - A "wrong" code example extracted from the rule's documentation
/// - A "fix" code example extracted from the rule's documentation
/// - Unit-test guidelines for verifying the fix
///
/// Usage: `swift6-analyzer <path> --report assistant --output agent-input.json`
public struct AssistantReporter: Reporter {

    /// Optional path to the `Docs/Rules/` directory. When nil, docs are not embedded.
    public let docsPath: URL?

    public init(docsPath: URL? = nil) {
        self.docsPath = docsPath
    }

    // MARK: - Codable output model

    struct ProjectSummary: Encodable {
        let projectName: String
        let generatedAt: String
        let totalErrorFindings: Int
        let totalWarningFindings: Int
        let totalScore: Double
        let modules: [ModuleSummary]
    }

    struct ModuleSummary: Encodable {
        let module: String
        let status: [String]
        let score: Double
        let findings: [AssistantFinding]
    }

    struct AssistantFinding: Encodable {
        let file: String
        let line: Int
        let column: Int
        let severity: String
        let rule: String
        let weight: Double
        let message: String
        let referenceWrong: String?
        let referenceFix: String?
        let unitTestGuideline: String
    }

    // MARK: - Reporter conformance

    public func generate(findings: [Finding]) -> String {
        let summary = ProjectSummary(
            projectName: "Unknown",
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            totalErrorFindings: findings.filter { $0.severity == .error }.count,
            totalWarningFindings: findings.filter { $0.severity == .warning }.count,
            totalScore: FindingComplexity.errorScore(for: findings),
            modules: []
        )
        return encode(summary)
    }

    public func generate(modules: [ModuleResult], projectName: String) -> String {
        let rootPath = longestCommonPathPrefix(modules.map { $0.path })
        let allFindings = modules.flatMap { $0.findings }

        let moduleSummaries: [ModuleSummary] = modules.map { module in
            let findings = module.findings.map { f -> AssistantFinding in
                let docs    = ruleDocs(for: f.rule)
                let relFile = relativePath(f.file, root: rootPath)
                return AssistantFinding(
                    file: relFile,
                    line: f.line,
                    column: f.column,
                    severity: f.severity.rawValue,
                    rule: f.rule,
                    weight: FindingComplexity.weight(for: f.rule),
                    message: f.message,
                    referenceWrong: docs?.wrongExample,
                    referenceFix: docs?.fixExample,
                    unitTestGuideline: unitTestGuideline(for: f)
                )
            }
            return ModuleSummary(
                module: module.qualifiedName,
                status: module.aggregateStatus.tags.map(\.rawValue).sorted(),
                score: module.aggregateScore,
                findings: findings
            )
        }

        let summary = ProjectSummary(
            projectName: projectName,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            totalErrorFindings: allFindings.filter { $0.severity == .error }.count,
            totalWarningFindings: allFindings.filter { $0.severity == .warning }.count,
            totalScore: FindingComplexity.errorScore(for: allFindings),
            modules: moduleSummaries
        )

        return encode(summary)
    }

    // MARK: - Rule doc parsing

    private struct RuleDocs {
        let wrongExample: String
        let fixExample: String
    }

    private func ruleDocs(for rule: String) -> RuleDocs? {
        guard let docsPath else { return nil }
        let mdURL = docsPath.appendingPathComponent("\(rule).md")
        guard let content = try? String(contentsOf: mdURL, encoding: .utf8) else { return nil }
        return parseRuleDocs(content)
    }

    /// Extracts the first ❌ Wrong code block and the first ✅ Correct code block from a rule .md file.
    private func parseRuleDocs(_ markdown: String) -> RuleDocs? {
        func extractFirstCodeBlock(after marker: String, in text: String) -> String? {
            guard let markerRange = text.range(of: marker) else { return nil }
            let afterMarker = String(text[markerRange.upperBound...])
            guard let fenceStart = afterMarker.range(of: "```swift") else { return nil }
            let afterFence = String(afterMarker[fenceStart.upperBound...])
            guard let fenceEnd = afterFence.range(of: "```") else { return nil }
            return String(afterFence[..<fenceEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let wrong = extractFirstCodeBlock(after: "## ❌ Wrong", in: markdown)
            ?? extractFirstCodeBlock(after: "## Wrong", in: markdown)
        let fix   = extractFirstCodeBlock(after: "## ✅ Correct", in: markdown)
            ?? extractFirstCodeBlock(after: "## Correct", in: markdown)

        guard wrong != nil || fix != nil else { return nil }
        return RuleDocs(wrongExample: wrong ?? "", fixExample: fix ?? "")
    }

    // MARK: - Unit test guideline

    private func unitTestGuideline(for finding: Finding) -> String {
        let weight = FindingComplexity.weight(for: finding.rule)
        let effort = weight >= 0.8 ? "architectural" : weight >= 0.6 ? "moderate" : "straightforward"
        return """
        Write a Swift Testing @Test that verifies the fixed version of \
        '\(finding.file.components(separatedBy: "/").last ?? finding.file)' \
        no longer triggers \(finding.rule). \
        Effort level: \(effort) (weight \(weight)). \
        The test should: \
        1) Instantiate \(finding.rule)(), \
        2) Parse the fixed source via SwiftParser, \
        3) Call analyze(tree:file:locationConverter:), \
        4) #expect(findings.isEmpty) — no violations in the corrected code. \
        Also add a positive case confirming the original pattern IS still detected.
        """
    }

    // MARK: - Helpers

    private func relativePath(_ path: String, root: String) -> String {
        guard !root.isEmpty, path.hasPrefix(root) else { return path }
        var rel = String(path.dropFirst(root.count))
        if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
        return rel.isEmpty ? path : rel
    }

    private func longestCommonPathPrefix(_ paths: [String]) -> String {
        guard !paths.isEmpty else { return "" }
        var components = paths[0].components(separatedBy: "/")
        for path in paths.dropFirst() {
            let other = path.components(separatedBy: "/")
            var i = 0
            while i < components.count && i < other.count && components[i] == other[i] { i += 1 }
            components = Array(components.prefix(i))
        }
        return components.joined(separator: "/")
    }

    private func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}
