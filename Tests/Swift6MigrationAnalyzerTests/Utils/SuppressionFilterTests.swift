import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("SuppressionFilter")
struct SuppressionFilterTests {

    // MARK: - Same-line suppression (suppress all)

    @Test("Suppresses finding when same line has 'swift6-analyzer: ignore'")
    func suppressesSameLineAllRules() {
        let source = "var x = 0 // swift6-analyzer: ignore"
        let finding = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.isEmpty)
    }

    @Test("Suppresses finding when same line has 'swift6-analyzer: ignore' with trailing whitespace")
    func suppressesSameLineTrimmed() {
        let source = "var x = 0 // swift6-analyzer: ignore   "
        let finding = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.isEmpty)
    }

    // MARK: - Same-line suppression (suppress specific rule)

    @Test("Suppresses finding when same line names the matching rule")
    func suppressesSameLineSpecificRule() {
        let source = "var x = 0 // swift6-analyzer: ignore GlobalMutableStateRule"
        let finding = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.isEmpty)
    }

    @Test("Does NOT suppress finding when same line names a different rule")
    func doesNotSuppressWrongRule() {
        let source = "var x = 0 // swift6-analyzer: ignore DispatchQueueRule"
        let finding = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.count == 1)
    }

    // MARK: - Previous-line suppression

    @Test("Suppresses finding when line above has ignore comment (all rules)")
    func suppressesPreviousLineAllRules() {
        let source = """
        // swift6-analyzer: ignore
        var globalState = 0
        """
        let finding = makeFinding(file: "T.swift", line: 2, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.isEmpty)
    }

    @Test("Suppresses finding when line above names matching rule")
    func suppressesPreviousLineSpecificRule() {
        let source = """
        // swift6-analyzer: ignore GlobalMutableStateRule
        var globalState = 0
        """
        let finding = makeFinding(file: "T.swift", line: 2, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.isEmpty)
    }

    @Test("Does NOT suppress when line above names a different rule")
    func doesNotSuppressPreviousLineWrongRule() {
        let source = """
        // swift6-analyzer: ignore DispatchQueueRule
        var globalState = 0
        """
        let finding = makeFinding(file: "T.swift", line: 2, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.count == 1)
    }

    // MARK: - Non-suppression

    @Test("Does not suppress finding on unrelated line")
    func doesNotSuppressUnrelatedLine() {
        let source = """
        // swift6-analyzer: ignore
        let safe = 0
        var notSuppressed = 1
        """
        // Finding is on line 3 — suppression is on line 1 (two lines above line 3)
        let finding = makeFinding(file: "T.swift", line: 3, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.count == 1)
    }

    @Test("Does not suppress when no ignore comment is present")
    func doesNotSuppressNoComment() {
        let source = "var x = 0"
        let finding = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.count == 1)
    }

    @Test("Does not suppress when comment uses wrong prefix")
    func doesNotSuppressWrongPrefix() {
        let source = "var x = 0 // analyzer: ignore"
        let finding = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.count == 1)
    }

    // MARK: - Multiple findings

    @Test("Selectively suppresses only matching findings in a multi-finding list")
    func selectivelySuppresses() {
        let source = """
        var x = 0 // swift6-analyzer: ignore GlobalMutableStateRule
        var y = 0
        """
        let f1 = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let f2 = makeFinding(file: "T.swift", line: 2, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [f1, f2], source: source)
        #expect(result.count == 1)
        #expect(result[0].line == 2)
    }

    @Test("Returns empty when all findings are suppressed")
    func allSuppressed() {
        let source = """
        var a = 0 // swift6-analyzer: ignore
        var b = 0 // swift6-analyzer: ignore
        """
        let f1 = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let f2 = makeFinding(file: "T.swift", line: 2, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [f1, f2], source: source)
        #expect(result.isEmpty)
    }

    @Test("Returns all findings unchanged when source is empty")
    func emptySourceReturnsFindings() {
        let finding = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: "")
        #expect(result.count == 1)
    }

    @Test("Returns empty immediately when findings list is empty")
    func emptyFindingsReturnsEmpty() {
        let result = SuppressionFilter.filter(findings: [], source: "var x = 0 // swift6-analyzer: ignore")
        #expect(result.isEmpty)
    }

    // MARK: - Whole-file suppression (disable-file)

    @Test("Suppresses all findings when first line has 'swift6-analyzer: disable-file'")
    func suppressesEntireFileWithDisableFile() {
        let source = """
        // swift6-analyzer: disable-file
        var x = 0
        var y = 0
        """
        let f1 = makeFinding(file: "T.swift", line: 2, rule: "GlobalMutableStateRule")
        let f2 = makeFinding(file: "T.swift", line: 3, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [f1, f2], source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not suppress when disable-file marker is NOT on the first line")
    func doesNotSuppressDisableFileOnNonFirstLine() {
        let source = """
        var x = 0
        // swift6-analyzer: disable-file
        var y = 0
        """
        let finding = makeFinding(file: "T.swift", line: 1, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.count == 1)
    }

    @Test("disable-file works even when there is only one finding")
    func disableFileSingleFinding() {
        let source = "// swift6-analyzer: disable-file\nvar x = 0"
        let finding = makeFinding(file: "T.swift", line: 2, rule: "GlobalMutableStateRule")
        let result = SuppressionFilter.filter(findings: [finding], source: source)
        #expect(result.isEmpty)
    }

    @Test("disable-file returns empty for an empty findings list")
    func disableFileEmptyFindings() {
        let source = "// swift6-analyzer: disable-file\nvar x = 0"
        let result = SuppressionFilter.filter(findings: [], source: source)
        #expect(result.isEmpty)
    }
}
