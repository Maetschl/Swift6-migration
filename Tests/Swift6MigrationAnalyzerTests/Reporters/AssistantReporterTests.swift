import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("AssistantReporter")
struct AssistantReporterTests {

    let reporter = AssistantReporter(docsPath: nil)

    // MARK: - Schema / JSON validity

    @Test("Output is valid JSON")
    func outputIsValidJSON() throws {
        let modules = [makeModuleResult(name: "M", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        _ = try JSONSerialization.jsonObject(with: data)
    }

    @Test("Output contains projectName field")
    func containsProjectName() {
        let output = reporter.generate(modules: [], projectName: "MyApp")
        #expect(output.contains("\"projectName\""))
        #expect(output.contains("MyApp"))
    }

    @Test("Output contains generatedAt ISO8601 timestamp")
    func containsGeneratedAt() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("\"generatedAt\""))
        #expect(output.contains("T") && output.contains("Z"))
    }

    @Test("Output contains modules array")
    func containsModulesArray() throws {
        let modules = [makeModuleResult(name: "Alpha", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["modules"] != nil)
    }

    // MARK: - Finding fields

    @Test("Each finding has file, line, column, severity, rule, and message fields")
    func findingHasRequiredFields() throws {
        let finding = Finding(
            file: "/proj/Auth.swift", line: 15, column: 4,
            severity: .error, rule: "GlobalMutableStateRule", message: "Test msg"
        )
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArr = try #require(json["modules"] as? [[String: Any]])
        let findings = try #require(modulesArr[0]["findings"] as? [[String: Any]])
        let first = try #require(findings.first)
        #expect(first["line"] as? Int == 15)
        #expect(first["column"] as? Int == 4)
        #expect(first["severity"] as? String == "error")
        #expect(first["rule"] as? String == "GlobalMutableStateRule")
        #expect(first["message"] as? String == "Test msg")
    }

    @Test("Finding file path is reported relative to common root when multiple modules share a prefix")
    func findingFileIsRelativeWithSharedPrefix() throws {
        // Module paths are /fake/Auth and /fake/Dashboard (from makeModuleResult).
        // Finding file paths must be inside those module trees to share the /fake/ prefix.
        let f1 = Finding(file: "/fake/Auth/Login.swift", line: 1, column: 1, severity: .warning, rule: "DispatchQueueRule", message: "msg")
        let f2 = Finding(file: "/fake/Dashboard/Feed.swift", line: 1, column: 1, severity: .warning, rule: "TimerRule", message: "msg")
        let m1 = makeModuleResult(name: "Auth", findings: [f1])
        let m2 = makeModuleResult(name: "Dashboard", findings: [f2])
        let output = reporter.generate(modules: [m1, m2], projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArr = try #require(json["modules"] as? [[String: Any]])
        let allFindings = modulesArr.flatMap { ($0["findings"] as? [[String: Any]]) ?? [] }
        for finding in allFindings {
            let filePath = try #require(finding["file"] as? String)
            // Common root /fake/ is stripped — relative path must not start with /fake/
            #expect(!filePath.hasPrefix("/fake/"))
        }
    }

    @Test("Finding weight matches FindingComplexity table")
    func findingWeightMatchesTable() throws {
        let finding = Finding(
            file: "/proj/A.swift", line: 1, column: 1,
            severity: .error, rule: "UncheckedSendableRule", message: "msg"
        )
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArr = try #require(json["modules"] as? [[String: Any]])
        let findings = try #require(modulesArr[0]["findings"] as? [[String: Any]])
        let weight = try #require(findings[0]["weight"] as? Double)
        #expect(weight == 1.0)
    }

    // MARK: - Unit test guideline

    @Test("Finding includes unitTestGuideline field")
    func findingHasUnitTestGuideline() {
        let finding = makeFinding(rule: "DispatchQueueRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("unitTestGuideline"))
    }

    @Test("Unit test guideline mentions the rule name")
    func unitTestGuidelineMentionsRule() throws {
        let finding = makeFinding(rule: "UncheckedSendableRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArr = try #require(json["modules"] as? [[String: Any]])
        let findings = try #require(modulesArr[0]["findings"] as? [[String: Any]])
        let guideline = try #require(findings[0]["unitTestGuideline"] as? String)
        #expect(guideline.contains("UncheckedSendableRule"))
    }

    @Test("Unit test guideline describes architectural effort for high-weight rules")
    func unitTestGuidelineDescribesArchitecturalEffort() throws {
        let finding = makeFinding(rule: "UncheckedSendableRule")  // weight 1.0
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArr = try #require(json["modules"] as? [[String: Any]])
        let findings = try #require(modulesArr[0]["findings"] as? [[String: Any]])
        let guideline = try #require(findings[0]["unitTestGuideline"] as? String)
        #expect(guideline.contains("architectural"))
    }

    // MARK: - No-docs mode (docsPath nil)

    @Test("referenceWrong and referenceFix are omitted from JSON when docsPath is nil")
    func referenceFieldsAreOmittedWithoutDocs() throws {
        let finding = makeFinding(rule: "DispatchQueueRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArr = try #require(json["modules"] as? [[String: Any]])
        let findings = try #require(modulesArr[0]["findings"] as? [[String: Any]])
        let first = try #require(findings.first)
        // Swift's JSONEncoder omits nil Optional fields entirely — keys must be absent
        // (they are not encoded as JSON null)
        #expect(!first.keys.contains("referenceWrong") || first["referenceWrong"] == nil)
        #expect(!first.keys.contains("referenceFix") || first["referenceFix"] == nil)
    }

    // MARK: - Module-level fields

    @Test("Module summary contains status, score and findings")
    func moduleSummaryHasRequiredFields() throws {
        let modules = [makeModuleResult(name: "Auth", findings: [makeFinding()])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArr = try #require(json["modules"] as? [[String: Any]])
        let first = try #require(modulesArr.first)
        #expect(first["module"] != nil)
        #expect(first["status"] != nil)
        #expect(first["score"] != nil)
        #expect(first["findings"] != nil)
    }

    // MARK: - Totals

    @Test("totalErrorFindings counts only .error findings")
    func totalErrorFindingsCountsErrors() throws {
        let findings = [
            makeFinding(severity: .error, rule: "GlobalMutableStateRule"),
            makeFinding(severity: .warning, rule: "DispatchQueueRule")
        ]
        let modules = [makeModuleResult(name: "M", findings: findings)]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let total = try #require(json["totalErrorFindings"] as? Int)
        #expect(total == 1)
    }

    @Test("totalWarningFindings counts only .warning findings")
    func totalWarningFindingsCountsWarnings() throws {
        let findings = [
            makeFinding(severity: .error, rule: "GlobalMutableStateRule"),
            makeFinding(severity: .warning, rule: "DispatchQueueRule"),
            makeFinding(severity: .warning, rule: "TimerRule")
        ]
        let modules = [makeModuleResult(name: "M", findings: findings)]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let total = try #require(json["totalWarningFindings"] as? Int)
        #expect(total == 2)
    }

    // MARK: - Flat report (legacy)

    @Test("Flat report generate(findings:) is valid JSON")
    func flatReportIsValidJSON() throws {
        let output = reporter.generate(findings: [makeFinding()])
        let data = try #require(output.data(using: .utf8))
        _ = try JSONSerialization.jsonObject(with: data)
    }
}
