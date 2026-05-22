import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("DiffReporter")
struct DiffReporterTests {
    let reporter = DiffReporter()

    @Test("No regressions text is shown when there are no new findings")
    func noRegressionsMessage() {
        let diff = BaselineDiff()
        let output = reporter.generate(diff: diff, projectName: "MyProject")
        #expect(output.contains("_No regressions — 🎉_"))
    }

    @Test("New findings section formats each finding")
    func newFindingsFormat() {
        let diff = BaselineDiff(
            newFindings: [
                Finding(file: "Sources/Feature/File.swift", line: 22, column: 8, severity: .error, rule: "GlobalMutableStateRule", message: "message")
            ]
        )

        let output = reporter.generate(diff: diff, projectName: "MyProject")
        #expect(output.contains("- 🔴 `Sources/Feature/File.swift:22` — [GlobalMutableStateRule] message"))
    }

    @Test("Resolved findings are struck through")
    func resolvedFindingsStrikethrough() {
        let diff = BaselineDiff(
            resolvedFindings: [
                Finding(file: "Sources/Feature/OldFile.swift", line: 10, column: 1, severity: .warning, rule: "DispatchQueueRule", message: "message")
            ]
        )

        let output = reporter.generate(diff: diff, projectName: "MyProject")
        #expect(output.contains("- ~~`Sources/Feature/OldFile.swift:10`~~ — [DispatchQueueRule] message"))
    }

    @Test("Positive score delta is shown with regression marker")
    func positiveScoreDelta() {
        let diff = BaselineDiff(scoreDeltas: ["FeatureA": 0.7], totalScoreDelta: 0.7)
        let output = reporter.generate(diff: diff, projectName: "MyProject")
        #expect(output.contains("| FeatureA | +0.70 🔴 |"))
        #expect(output.contains("+0.70 (regression)"))
    }

    @Test("Negative score delta is shown with improvement marker")
    func negativeScoreDelta() {
        let diff = BaselineDiff(scoreDeltas: ["FeatureA": -1.4], totalScoreDelta: -1.4)
        let output = reporter.generate(diff: diff, projectName: "MyProject")
        #expect(output.contains("| FeatureA | -1.40 ✅ |"))
        #expect(output.contains("-1.40 (improvement)"))
    }

    @Test("Summary table shows correct values")
    func summaryTableValues() {
        let diff = BaselineDiff(
            newFindings: [
                Finding(file: "Sources/A.swift", line: 1, column: 1, severity: .error, rule: "RuleA", message: "a"),
                Finding(file: "Sources/B.swift", line: 2, column: 1, severity: .warning, rule: "RuleB", message: "b")
            ],
            resolvedFindings: [
                Finding(file: "Sources/C.swift", line: 3, column: 1, severity: .warning, rule: "RuleC", message: "c")
            ],
            totalScoreDelta: -2.1
        )

        let output = reporter.generate(diff: diff, projectName: "MyProject")
        #expect(output.contains("| 🆕 New findings | 2 |"))
        #expect(output.contains("| ✅ Resolved findings | 1 |"))
        #expect(output.contains("| 📊 Score delta | -2.10 (improvement) |"))
    }
}
