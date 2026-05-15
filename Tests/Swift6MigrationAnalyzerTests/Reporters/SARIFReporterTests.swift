import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("SARIFReporter")
struct SARIFReporterTests {

    let reporter = SARIFReporter()

    // MARK: - Schema compliance

    @Test("Output is valid JSON")
    func outputIsValidJSON() throws {
        let modules = [makeModuleResult(name: "M", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        _ = try JSONSerialization.jsonObject(with: data)
    }

    @Test("Output contains SARIF version 2.1.0")
    func containsVersion() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("2.1.0"))
    }

    @Test("Output contains $schema field pointing to SARIF 2.1.0 schema URL")
    func containsSchemaURL() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("sarif-schema-2.1.0.json"))
    }

    @Test("Output contains a runs array")
    func containsRunsArray() throws {
        let output = reporter.generate(modules: [], projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        #expect(runs.count == 1)
    }

    @Test("Tool driver has name swift6-analyzer")
    func toolDriverName() throws {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("swift6-analyzer"))
    }

    // MARK: - Results mapping

    @Test("Each finding becomes one SARIF result")
    func findingMapsToResult() throws {
        let findings = [
            makeFinding(file: "/proj/A.swift", line: 10, severity: .error, rule: "UncheckedSendableRule"),
            makeFinding(file: "/proj/B.swift", line: 20, severity: .warning, rule: "DispatchQueueRule")
        ]
        let modules = [makeModuleResult(name: "M", findings: findings)]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        let results = try #require(runs[0]["results"] as? [[String: Any]])
        #expect(results.count == 2)
    }

    @Test(".error severity maps to SARIF level 'error'")
    func errorMapsToErrorLevel() throws {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding(severity: .error, rule: "GlobalMutableStateRule")])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        let results = try #require(runs[0]["results"] as? [[String: Any]])
        let first = try #require(results.first)
        #expect(first["level"] as? String == "error")
    }

    @Test(".warning severity maps to SARIF level 'warning'")
    func warningMapsToWarningLevel() throws {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding(severity: .warning, rule: "DispatchQueueRule")])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        let results = try #require(runs[0]["results"] as? [[String: Any]])
        let first = try #require(results.first)
        #expect(first["level"] as? String == "warning")
    }

    @Test("Result ruleId matches finding rule name")
    func ruleIdMatchesFindingRule() throws {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding(rule: "UncheckedSendableRule")])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        let results = try #require(runs[0]["results"] as? [[String: Any]])
        let first = try #require(results.first)
        #expect(first["ruleId"] as? String == "UncheckedSendableRule")
    }

    @Test("Location contains startLine and startColumn")
    func locationContainsLineAndColumn() throws {
        let finding = Finding(file: "/proj/A.swift", line: 42, column: 8, severity: .warning, rule: "DispatchQueueRule", message: "msg")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        let results = try #require(runs[0]["results"] as? [[String: Any]])
        let first = try #require(results.first)
        let locations = try #require(first["locations"] as? [[String: Any]])
        let physLoc = try #require(locations[0]["physicalLocation"] as? [String: Any])
        let region = try #require(physLoc["region"] as? [String: Any])
        #expect(region["startLine"] as? Int == 42)
        #expect(region["startColumn"] as? Int == 8)
    }

    @Test("Artifact location uses %SRCROOT% as uriBaseId")
    func artifactLocationUsesSRCROOT() {
        let output = reporter.generate(modules: [makeModuleResult(name: "M", findings: [makeFinding(file: "/proj/A.swift")])], projectName: "P")
        #expect(output.contains("SRCROOT"))
    }

    // MARK: - Rule descriptors

    @Test("Tool driver rules list includes all unique rule IDs from findings")
    func ruleDescriptorsIncludeAllRules() throws {
        let findings = [
            makeFinding(rule: "UncheckedSendableRule"),
            makeFinding(rule: "DispatchQueueRule"),
            makeFinding(rule: "DispatchQueueRule")  // duplicate — should appear once
        ]
        let modules = [makeModuleResult(name: "M", findings: findings)]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        let tool = try #require(runs[0]["tool"] as? [String: Any])
        let driver = try #require(tool["driver"] as? [String: Any])
        let rules = try #require(driver["rules"] as? [[String: Any]])
        let ruleIds = rules.compactMap { $0["id"] as? String }
        #expect(ruleIds.contains("UncheckedSendableRule"))
        #expect(ruleIds.contains("DispatchQueueRule"))
        #expect(ruleIds.count == 2)   // no duplicates
    }

    // MARK: - Empty input

    @Test("Empty findings produce empty results array")
    func emptyFindingsProduceEmptyResults() throws {
        let output = reporter.generate(modules: [makeModuleResult(name: "M", findings: [])], projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        let results = try #require(runs[0]["results"] as? [[String: Any]])
        #expect(results.isEmpty)
    }
}
