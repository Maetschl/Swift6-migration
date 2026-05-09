import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("JSONReporter")
struct JSONReporterTests {

    let reporter = JSONReporter()

    // MARK: - Module report

    @Test("Output is valid JSON")
    func outputIsValidJSON() throws {
        let modules = [makeModuleResult(name: "M", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        _ = try JSONSerialization.jsonObject(with: data)
    }

    @Test("JSON contains projectName field")
    func containsProjectName() throws {
        let output = reporter.generate(modules: [], projectName: "MyApp")
        #expect(output.contains("\"projectName\""))
        #expect(output.contains("MyApp"))
    }

    @Test("JSON contains status field")
    func containsStatusField() throws {
        let modules = [makeModuleResult(name: "M", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("\"status\""))
    }

    @Test("JSON status is Migrated when score is 0")
    func statusIsMigratedForClean() throws {
        let modules = [makeModuleResult(name: "M", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Migrated"))
    }

    @Test("JSON status is Pending Migration when findings exist")
    func statusIsPendingWhenFindingsExist() {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding(severity: .error)])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Pending Migration"))
    }

    @Test("JSON contains totalScore field")
    func containsTotalScore() {
        let finding = makeFinding(rule: "UncheckedSendableRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("\"totalScore\""))
        #expect(output.contains("1"))
    }

    @Test("JSON contains modules array")
    func containsModulesArray() throws {
        let modules = [
            makeModuleResult(name: "Alpha", findings: []),
            makeModuleResult(name: "Beta", findings: [makeFinding()])
        ]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArray = try #require(json["modules"] as? [[String: Any]])
        #expect(modulesArray.count == 2)
    }

    @Test("JSON contains summaryByRule array")
    func containsSummaryByRule() {
        let finding = makeFinding(rule: "ForceUnwrapRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("\"summaryByRule\""))
        #expect(output.contains("scoreContribution"))
    }

    @Test("JSON contains complexityWeightTable array")
    func containsComplexityWeightTable() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("\"complexityWeightTable\""))
        #expect(output.contains("rationale"))
    }

    @Test("JSON contains generatedAt ISO8601 timestamp")
    func containsGeneratedAt() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("\"generatedAt\""))
        // ISO8601 dates contain 'T' separator and 'Z' suffix
        #expect(output.contains("T") && output.contains("Z"))
    }

    @Test("Each module in JSON has findings array, score, and status")
    func moduleHasRequiredFields() throws {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding()])]
        let output = reporter.generate(modules: modules, projectName: "P")
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let modulesArray = try #require(json["modules"] as? [[String: Any]])
        let first = try #require(modulesArray.first)
        #expect(first["findings"] != nil)
        #expect(first["score"] != nil)
        #expect(first["status"] != nil)
    }

    // MARK: - Flat report

    @Test("Flat report output is valid JSON")
    func flatReportIsValidJSON() throws {
        let output = reporter.generate(findings: [makeFinding()])
        let data = try #require(output.data(using: .utf8))
        _ = try JSONSerialization.jsonObject(with: data)
    }

    @Test("Flat report contains totalFindings count")
    func flatReportContainsTotalFindings() throws {
        let output = reporter.generate(findings: [makeFinding(), makeFinding()])
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let total = try #require(json["totalFindings"] as? Int)
        #expect(total == 2)
    }
}


// MARK: - Hierarchy & aggregate fields (appended)

extension JSONReporterTests {

    @Test("JSON module contains aggregateScore field")
    func jsonHasAggregateScore() {
        let child = makeModuleResult(
            name: "Sub", findings: [makeFinding(rule: "UncheckedSendableRule")],
            depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent", findings: [],
            depth: 0, childQualifiedNames: ["Parent/Sub"],
            aggregateScore: 1.0
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("aggregateScore"))
    }

    @Test("JSON module contains aggregateStatus field")
    func jsonHasAggregateStatus() {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding()])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("aggregateStatus"))
    }

    @Test("JSON module contains childQualifiedNames array")
    func jsonHasChildQualifiedNames() {
        let parent = makeModuleResult(
            name: "Parent", findings: [],
            depth: 0, childQualifiedNames: ["Parent/Sub"]
        )
        let output = reporter.generate(modules: [parent], projectName: "P")
        #expect(output.contains("childQualifiedNames"))
        #expect(output.contains("Parent"))  // slash JSON-escaped as \/
    }

    @Test("JSON module contains qualifiedName field")
    func jsonHasQualifiedName() {
        let child = makeModuleResult(
            name: "Sub", findings: [],
            depth: 1, parentQualifiedName: "Parent"
        )
        let output = reporter.generate(modules: [child], projectName: "P")
        #expect(output.contains("qualifiedName"))
        #expect(output.contains("Parent"))  // slash JSON-escaped as \/
    }

    @Test("JSON module contains parentQualifiedName field for nested module")
    func jsonHasParentQualifiedName() {
        let child = makeModuleResult(
            name: "Sub", findings: [],
            depth: 1, parentQualifiedName: "Parent"
        )
        let output = reporter.generate(modules: [child], projectName: "P")
        #expect(output.contains("parentQualifiedName"))
    }
}
