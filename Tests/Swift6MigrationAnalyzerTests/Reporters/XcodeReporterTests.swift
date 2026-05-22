import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("XcodeReporter")
struct XcodeReporterTests {
    let reporter = XcodeReporter()

    @Test("Empty findings emit no-findings marker")
    func emptyFindings() {
        let output = reporter.generate(modules: [], projectName: "MyProject")
        #expect(output == "// swift6-analyzer: no findings")
    }

    @Test("Error finding renders as error line")
    func errorFindingFormat() {
        let finding = Finding(
            file: "/absolute/path/File.swift",
            line: 45,
            column: 4,
            severity: .error,
            rule: "GlobalMutableStateRule",
            message: "Global variable 'cache' is not concurrency-safe"
        )

        let output = reporter.generate(modules: [makeModuleResult(name: "Core", findings: [finding])], projectName: "MyProject")
        #expect(output == "/absolute/path/File.swift:45:4: error: [GlobalMutableStateRule] Global variable 'cache' is not concurrency-safe")
    }

    @Test("Warning finding renders as warning line")
    func warningFindingFormat() {
        let finding = Finding(
            file: "/absolute/path/File.swift",
            line: 22,
            column: 8,
            severity: .warning,
            rule: "DispatchQueueRule",
            message: "Prefer @MainActor or structured concurrency over DispatchQueue.main.async"
        )

        let output = reporter.generate(modules: [makeModuleResult(name: "Core", findings: [finding])], projectName: "MyProject")
        #expect(output == "/absolute/path/File.swift:22:8: warning: [DispatchQueueRule] Prefer @MainActor or structured concurrency over DispatchQueue.main.async")
    }

    @Test("Multiple findings are sorted by file path then line")
    func findingsAreSorted() {
        let findings = [
            Finding(file: "/z/File.swift", line: 1, column: 1, severity: .warning, rule: "RuleC", message: "third"),
            Finding(file: "/a/File.swift", line: 10, column: 1, severity: .warning, rule: "RuleB", message: "second"),
            Finding(file: "/a/File.swift", line: 2, column: 1, severity: .error, rule: "RuleA", message: "first")
        ]

        let output = reporter.generate(modules: [makeModuleResult(name: "Core", findings: findings)], projectName: "MyProject")
        let lines = output.components(separatedBy: "\n")

        #expect(lines.count == 3)
        #expect(lines[0].contains("/a/File.swift:2:1"))
        #expect(lines[1].contains("/a/File.swift:10:1"))
        #expect(lines[2].contains("/z/File.swift:1:1"))
    }

    @Test("Info severity maps to warning")
    func infoMapsToWarning() {
        let finding = Finding(
            file: "/absolute/path/File.swift",
            line: 12,
            column: 3,
            severity: .info,
            rule: "DispatchQueueRule",
            message: "Consider isolating this API"
        )

        let output = reporter.generate(modules: [makeModuleResult(name: "Core", findings: [finding])], projectName: "MyProject")
        #expect(output.contains(": warning: [DispatchQueueRule] Consider isolating this API"))
    }

    @Test("Rule name is prefixed in brackets")
    func ruleNamePrefix() {
        let finding = Finding(
            file: "/absolute/path/File.swift",
            line: 7,
            column: 9,
            severity: .warning,
            rule: "DispatchQueueRule",
            message: "Prefer @MainActor"
        )

        let output = reporter.generate(modules: [makeModuleResult(name: "Core", findings: [finding])], projectName: "MyProject")
        #expect(output.contains("[DispatchQueueRule] Prefer @MainActor"))
    }
}
