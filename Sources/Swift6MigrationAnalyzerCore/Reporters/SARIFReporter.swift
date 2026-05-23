import Foundation

/// Generates a SARIF 2.1.0 report for GitHub Advanced Security / code scanning.
///
/// SARIF (Static Analysis Results Interchange Format) is the standard format accepted
/// by GitHub's code-scanning feature. Uploading a SARIF file to a repository causes
/// findings to appear as inline annotations on pull-request diffs and in the Security tab.
///
/// Usage: `swift6-analyzer <path> --report sarif --output results.sarif`
///
/// Then upload via the GitHub CLI or API:
/// ```bash
/// gh code-scanning upload-sarif --sarif results.sarif
/// ```
public struct SARIFReporter: Reporter {
    public init() {}

    // MARK: - SARIF schema types (private)

    private struct SARIFOutput: Encodable {
        let version: String
        let schema: String
        let runs: [Run]

        enum CodingKeys: String, CodingKey {
            case version
            case schema = "$schema"
            case runs
        }
    }

    private struct Run: Encodable {
        let tool: Tool
        let results: [Result]
        let artifacts: [Artifact]
    }

    private struct Tool: Encodable {
        let driver: Driver
    }

    private struct Driver: Encodable {
        let name: String
        let version: String
        let informationUri: String
        let rules: [SARIFRule]
    }

    private struct SARIFRule: Encodable {
        let id: String
        let name: String
        let shortDescription: Message
        let helpUri: String
        let properties: RuleProperties
    }

    private struct RuleProperties: Encodable {
        let tags: [String]
        let precision: String
        let severity: String
        let securitySeverity: String?

        enum CodingKeys: String, CodingKey {
            case tags, precision
            case severity = "problem.severity"
            case securitySeverity = "security-severity"
        }
    }

    private struct Result: Encodable {
        let ruleId: String
        let level: String
        let message: Message
        let locations: [Location]
        let properties: ResultProperties
    }

    private struct ResultProperties: Encodable {
        let weight: Double
    }

    private struct Message: Encodable {
        let text: String
    }

    private struct Location: Encodable {
        let physicalLocation: PhysicalLocation
    }

    private struct PhysicalLocation: Encodable {
        let artifactLocation: ArtifactLocation
        let region: Region
    }

    private struct ArtifactLocation: Encodable {
        let uri: String
        let uriBaseId: String

        enum CodingKeys: String, CodingKey {
            case uri
            case uriBaseId = "uriBaseId"
        }
    }

    private struct Region: Encodable {
        let startLine: Int
        let startColumn: Int
    }

    private struct Artifact: Encodable {
        let location: ArtifactLocation
    }

    // MARK: - Reporter conformance

    public func generate(findings: [Finding]) -> String {
        generate(modules: [], projectName: "Unknown", flatFindings: findings)
    }

    public func generate(modules: [ModuleResult], projectName: String) -> String {
        generate(modules: modules, projectName: projectName, flatFindings: nil)
    }

    // MARK: - Core generation

    private func generate(
        modules: [ModuleResult],
        projectName: String,
        flatFindings: [Finding]?
    ) -> String {
        let allFindings = flatFindings ?? modules.flatMap { $0.findings }
        let rootPath = rootPrefix(for: allFindings.map { $0.file })

        // Build unique rule descriptors from findings
        let uniqueRules = uniqueRuleIds(from: allFindings)
        let ruleDescriptors = uniqueRules.map { makeRule(id: $0) }

        let results = allFindings.map { finding -> Result in
            let relUri = relativeUri(path: finding.file, root: rootPath)
            return Result(
                ruleId: finding.rule,
                level: sarifLevel(for: finding.severity),
                message: Message(text: finding.message),
                locations: [
                    Location(physicalLocation: PhysicalLocation(
                        artifactLocation: ArtifactLocation(uri: relUri, uriBaseId: "%SRCROOT%"),
                        region: Region(startLine: max(1, finding.line), startColumn: max(1, finding.column))
                    ))
                ],
                properties: ResultProperties(weight: FindingComplexity.weight(for: finding.rule))
            )
        }

        let uniqueFiles = Array(Set(allFindings.map { $0.file })).sorted()
        let artifacts = uniqueFiles.map { path in
            Artifact(location: ArtifactLocation(
                uri: relativeUri(path: path, root: rootPath),
                uriBaseId: "%SRCROOT%"
            ))
        }

        let sarifOutput = SARIFOutput(
            version: "2.1.0",
            schema: "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
            runs: [
                Run(
                    tool: Tool(driver: Driver(
                        name: "swift6-analyzer",
                        version: "1.2.0",
                        informationUri: "https://github.com/users/swift6-migration",
                        rules: ruleDescriptors
                    )),
                    results: results,
                    artifacts: artifacts
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(sarifOutput),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    // MARK: - Helpers

    private func sarifLevel(for severity: Severity) -> String {
        switch severity {
        case .error:   return "error"
        case .warning: return "warning"
        case .info:    return "note"
        }
    }

    private func uniqueRuleIds(from findings: [Finding]) -> [String] {
        var seen = Set<String>()
        return findings.compactMap { f in
            seen.insert(f.rule).inserted ? f.rule : nil
        }.sorted()
    }

    private func makeRule(id: String) -> SARIFRule {
        let entry = FindingComplexity.weightTable.first { $0.rule == id }
        let weight = entry?.weight ?? FindingComplexity.defaultWeight
        let rationale = entry?.rationale ?? "Swift 6 concurrency migration issue"
        let severity = weight >= 0.7 ? "error" : "warning"
        // SARIF security-severity: map weight to CVSS-like 0-10 scale for display
        let secSev = String(format: "%.1f", weight * 10.0)
        return SARIFRule(
            id: id,
            name: id,
            shortDescription: Message(text: rationale),
            helpUri: "https://github.com/users/swift6-migration/blob/main/Docs/Rules/\(id).md",
            properties: RuleProperties(
                tags: ["swift6", "concurrency", "migration"],
                precision: "high",
                severity: severity,
                securitySeverity: secSev
            )
        )
    }

    /// Computes the longest common path prefix for all file paths (to produce relative URIs).
    private func rootPrefix(for paths: [String]) -> String {
        guard !paths.isEmpty else { return "" }
        var components = paths[0].components(separatedBy: "/")
        for path in paths.dropFirst() {
            let other = path.components(separatedBy: "/")
            var i = 0
            while i < components.count && i < other.count && components[i] == other[i] { i += 1 }
            components = Array(components.prefix(i))
        }
        let prefix = components.joined(separator: "/")
        return prefix.isEmpty ? "" : prefix + "/"
    }

    private func relativeUri(path: String, root: String) -> String {
        guard !root.isEmpty, path.hasPrefix(root) else { return path }
        return String(path.dropFirst(root.count))
    }
}
