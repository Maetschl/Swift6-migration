import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("MarkdownReporter")
struct MarkdownReporterTests {

    let reporter = MarkdownReporter()

    // MARK: - Project overview

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
        let modules = [makeModuleResult(name: "Bad", findings: [makeFinding(severity: .error)])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Pending Migration"))
        #expect(output.contains("⏳"))
    }

    @Test("Report includes Migration Score")
    func includesMigrationScore() {
        let finding = makeFinding(severity: .error, rule: "UncheckedSendableRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Score") || output.contains("score"))
        #expect(output.contains("1.00"))
    }

    @Test("Report shows total file and line counts in overview")
    func showsTotals() {
        let modules = [makeModuleResult(name: "M", findings: [], fileCount: 5, linesOfCode: 200)]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("5"))
        #expect(output.contains("200"))
    }

    // MARK: - Module overview table

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

    @Test("Overview table contains Own Score and Subtree Score columns")
    func tableHasBothScoreColumns() {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding()])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Own Score"))
        #expect(output.contains("Subtree Score"))
    }

    @Test("Overview table contains Depth column")
    func tableHasDepthColumn() {
        let modules = [makeModuleResult(name: "M", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Depth"))
    }

    @Test("Container module shows aggregateStatus in table — pending when children have findings")
    func containerShowsPendingViaAggregate() {
        let child = makeModuleResult(
            name: "Sub",
            findings: [makeFinding(severity: .error)],
            depth: 1,
            parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent",
            findings: [],
            depth: 0,
            childQualifiedNames: ["Parent/Sub"],
            aggregateScore: child.score  // subtree includes child's score
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        // Parent's aggregateStatus should be pendingMigration (aggregateScore > 0)
        // The overview table should show ⏳ for parent
        #expect(output.contains("⏳"))
    }

    // MARK: - Per-module findings section (hierarchical)

    @Test("Report includes rule complexity weight in per-module section")
    func includesComplexityWeight() {
        let finding = makeFinding(severity: .error, rule: "ForceTryRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("0.8"))
    }

    @Test("Container module with no findings appears as group header when children have findings")
    func containerAppearsAsGroupHeaderForChildren() {
        let child = makeModuleResult(
            name: "Sub",
            findings: [makeFinding(severity: .error)],
            depth: 1,
            parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent",
            findings: [],
            depth: 0,
            childQualifiedNames: ["Parent/Sub"],
            aggregateScore: child.score
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        // Parent should appear as a group heading in the Findings section
        #expect(output.contains("Parent"))
        #expect(output.contains("Sub"))
        #expect(output.contains("No findings in this module directly"))
    }

    @Test("Container with no subtree findings is omitted from Findings section")
    func containerWithCleanSubtreeOmittedFromFindings() {
        let child = makeModuleResult(
            name: "CleanSub",
            findings: [],
            depth: 1,
            parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent",
            findings: [],
            depth: 0,
            childQualifiedNames: ["Parent/CleanSub"],
            aggregateScore: 0
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        // Neither parent nor child should appear in per-module findings section
        #expect(!output.contains("## ⏳ Parent"))
        #expect(!output.contains("## ✅ Parent"))
    }

    @Test("Findings section uses Findings heading")
    func findingsSectionHeader() {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding()])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("## Findings"))
    }

    @Test("Rule card heading does not conflict with module heading for depth-1 module")
    func ruleCardHeadingStable() {
        // depth-1 module uses ### heading; rule cards should use #### (one level below)
        let finding = makeFinding(severity: .error, rule: "ForceUnwrapRule")
        let child = makeModuleResult(
            name: "Sub",
            findings: [finding],
            depth: 1,
            parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent",
            findings: [],
            depth: 0,
            childQualifiedNames: ["Parent/Sub"],
            aggregateScore: child.score
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        // Module heading for depth-1 is ###; rule card should be ####
        #expect(output.contains("\n#### ForceUnwrapRule"))
        #expect(!output.contains("\n### ForceUnwrapRule "))
    }

    // MARK: - Summary by Rule

    @Test("Report includes Summary by Rule table")
    func containsSummaryByRule() {
        let finding = makeFinding(rule: "ForceUnwrapRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Summary by Rule"))
        #expect(output.contains("Score Contribution"))
    }

    // MARK: - Complexity table

    @Test("Report contains the complexity weight table section")
    func containsComplexityTable() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("Finding Complexity Weight Table"))
        #expect(output.contains("SUM(finding"))
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
        let findings = [makeFinding(rule: "ForceTryRule"), makeFinding(rule: "ForceUnwrapRule")]
        let output = reporter.generate(findings: findings)
        #expect(output.contains("ForceTryRule"))
        #expect(output.contains("ForceUnwrapRule"))
    }

    // MARK: - fix field rendering

    @Test("Finding with fix shows '💡 Fix:' blockquote in module findings")
    func findingWithFixShowsFixBlockquote() {
        let finding = Finding(
            file: "Test.swift", line: 1, severity: .error,
            rule: "GlobalMutableStateRule", message: "Not concurrency-safe",
            fix: "Annotate with @MainActor"
        )
        let modules = [makeModuleResult(name: "Core", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("💡 **Fix:**"))
        #expect(output.contains("Annotate with @MainActor"))
    }

    @Test("Finding without fix does not show '💡 Fix:' in module findings")
    func findingWithoutFixHasNoFixBlockquote() {
        let finding = Finding(
            file: "Test.swift", line: 1, severity: .error,
            rule: "GlobalMutableStateRule", message: "Not concurrency-safe"
        )
        let modules = [makeModuleResult(name: "Core", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(!output.contains("💡 **Fix:**"))
    }
}
