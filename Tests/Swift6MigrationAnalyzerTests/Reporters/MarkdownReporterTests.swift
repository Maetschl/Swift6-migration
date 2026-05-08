import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("MarkdownReporter")
struct MarkdownReporterTests {

    let reporter = MarkdownReporter()

    // MARK: - Module report structure

    @Test("Report contains project name in title")
    func containsProjectName() {
        let output = reporter.generate(modules: [], projectName: "MyProject")
        #expect(output.contains("MyProject"))
    }

    @Test("Report shows Migrated status for empty modules")
    func showsMigratedForCleanModules() {
        let modules = [makeModuleResult(name: "Clean", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Migrated"))
        #expect(output.contains("✅"))
    }

    @Test("Report shows Pending Migration status when findings exist")
    func showsPendingWhenFindingsExist() {
        let modules = [makeModuleResult(name: "Bad", findings: [makeFinding()])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Pending Migration"))
        #expect(output.contains("⏳"))
    }

    @Test("Report includes Migration Score")
    func includesMigrationScore() {
        let finding = makeFinding(rule: "UncheckedSendableRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Migration Score") || output.contains("score"))
        #expect(output.contains("1.00"))
    }

    @Test("Report lists each module in the Modules table")
    func listsModulesInTable() {
        let modules = [
            makeModuleResult(name: "Alpha", findings: []),
            makeModuleResult(name: "Beta",  findings: [makeFinding()])
        ]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Alpha"))
        #expect(output.contains("Beta"))
    }

    @Test("Report includes rule complexity weight in per-module section")
    func includesComplexityWeight() {
        let finding = makeFinding(severity: .error, rule: "ForceTryRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("0.8"))
    }

    @Test("Report contains the complexity weight table section")
    func containsComplexityTable() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("Finding Complexity Weight Table"))
        #expect(output.contains("SUM(finding"))
    }

    @Test("Report includes Summary by Rule table")
    func containsSummaryByRule() {
        let finding = makeFinding(rule: "ForceUnwrapRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Summary by Rule"))
        #expect(output.contains("Score Contribution"))
    }

    @Test("Migrated modules do not appear in per-module findings section")
    func migratedModulesSkippedInFindings() {
        let modules = [
            makeModuleResult(name: "CleanModule", findings: [])
        ]
        let output = reporter.generate(modules: modules, projectName: "P")
        // The heading "## ✅ CleanModule" or "## ⏳ CleanModule" should not appear
        // since there are no findings to list
        #expect(!output.contains("## ✅ CleanModule"))
    }

    @Test("Report shows total file and line counts in overview")
    func showsTotals() {
        let modules = [makeModuleResult(name: "M", findings: [], fileCount: 5, linesOfCode: 200)]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("5"))
        #expect(output.contains("200"))
    }

    // MARK: - Flat report (legacy)

    @Test("Flat report shows total findings count")
    func flatReportShowsTotalFindings() {
        let findings = [makeFinding(), makeFinding(), makeFinding()]
        let output = reporter.generate(findings: findings)
        #expect(output.contains("3"))
    }

    @Test("Flat report returns no-issues message for empty findings")
    func flatReportEmptyState() {
        let output = reporter.generate(findings: [])
        #expect(output.contains("No issues found"))
    }

    @Test("Flat report groups findings by rule name")
    func flatReportGroupsByRule() {
        let findings = [
            makeFinding(rule: "ForceTryRule"),
            makeFinding(rule: "ForceUnwrapRule")
        ]
        let output = reporter.generate(findings: findings)
        #expect(output.contains("ForceTryRule"))
        #expect(output.contains("ForceUnwrapRule"))
    }
}
