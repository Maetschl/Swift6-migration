import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("BaselineComparator")
struct BaselineComparatorTests {
    let comparator = BaselineComparator()

    @Test("Identical snapshots produce an empty diff")
    func identicalSnapshots() {
        let finding = Finding(file: "/proj/File.swift", line: 10, column: 2, severity: .error, rule: "DispatchQueueRule", message: "Use @MainActor")
        let module = makeModuleResult(name: "Feature", findings: [finding])

        let diff = comparator.compare(baseline: [module], current: [module])

        #expect(diff.newFindings.isEmpty)
        #expect(diff.resolvedFindings.isEmpty)
        #expect(diff.scoreDeltas.isEmpty)
        #expect(diff.totalScoreDelta == 0)
        #expect(diff.newModules.isEmpty)
        #expect(diff.removedModules.isEmpty)
    }

    @Test("New finding appears in newFindings")
    func newFindingAdded() {
        let baselineModule = makeModuleResult(name: "Feature", findings: [])
        let newFinding = Finding(file: "/proj/File.swift", line: 10, column: 2, severity: .error, rule: "DispatchQueueRule", message: "Use @MainActor")
        let currentModule = makeModuleResult(name: "Feature", findings: [newFinding])

        let diff = comparator.compare(baseline: [baselineModule], current: [currentModule])

        #expect(diff.newFindings.count == 1)
        #expect(diff.newFindings.first?.file == "/proj/File.swift")
        #expect(diff.resolvedFindings.isEmpty)
    }

    @Test("Removed finding appears in resolvedFindings")
    func findingRemoved() {
        let oldFinding = Finding(file: "/proj/File.swift", line: 10, column: 2, severity: .error, rule: "DispatchQueueRule", message: "Use @MainActor")
        let baselineModule = makeModuleResult(name: "Feature", findings: [oldFinding])
        let currentModule = makeModuleResult(name: "Feature", findings: [])

        let diff = comparator.compare(baseline: [baselineModule], current: [currentModule])

        #expect(diff.newFindings.isEmpty)
        #expect(diff.resolvedFindings.count == 1)
        #expect(diff.resolvedFindings.first?.rule == "DispatchQueueRule")
    }

    @Test("Score decrease produces negative total score delta")
    func scoreDecrease() {
        let baselineModule = makeModuleResult(
            name: "Feature",
            findings: [Finding(file: "/proj/File.swift", line: 10, column: 2, severity: .error, rule: "GlobalMutableStateRule", message: "Unsafe global")]
        )
        let currentModule = makeModuleResult(name: "Feature", findings: [])

        let diff = comparator.compare(baseline: [baselineModule], current: [currentModule])

        #expect(diff.totalScoreDelta < 0)
    }

    @Test("New module appears in newModules")
    func newModuleAdded() {
        let baselineModule = makeModuleResult(name: "FeatureA", findings: [])
        let currentModules = [
            baselineModule,
            makeModuleResult(name: "FeatureB", findings: [])
        ]

        let diff = comparator.compare(baseline: [baselineModule], current: currentModules)

        #expect(diff.newModules == ["FeatureB"])
    }

    @Test("Removed module appears in removedModules")
    func moduleRemoved() {
        let baselineModules = [
            makeModuleResult(name: "FeatureA", findings: []),
            makeModuleResult(name: "FeatureB", findings: [])
        ]
        let currentModules = [baselineModules[0]]

        let diff = comparator.compare(baseline: baselineModules, current: currentModules)

        #expect(diff.removedModules == ["FeatureB"])
    }
}
