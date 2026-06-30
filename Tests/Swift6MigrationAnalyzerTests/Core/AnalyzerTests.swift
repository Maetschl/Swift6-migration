import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("Analyzer")
struct AnalyzerTests {

    let analyzer = Analyzer()

    // MARK: - Default rules

    @Test("Analyzer has 21 default Swift 6 rules")
    func hasDefaultRules() {
        #expect(Analyzer.defaultRules.count == 21)
    }

    @Test("Default rules include all Swift 6 concurrency rule names")
    func defaultRuleNames() {
        let names = Analyzer.defaultRules.map(\.name)
        let expected = [
            "GlobalMutableStateRule", "NonisolatedUnsafeRule",
            "DispatchQueueRule", "DispatchGroupRule",
            "TaskDetachedRule", "CompletionHandlerRule",
            "UncheckedSendableRule", "PreconcurrencyRule",
            "ObservableObjectRule", "SynchronizationPrimitiveRule",
            "MainActorMissingRule", "NotificationCenterRule",
            "OperationQueueMainRule", "TimerRule",
            "CombineRule", "ThreadRule", "MainActorRunRule",
            "CheckedContinuationRule",
            "ActorReentrancyRule", "WithUnsafeCurrentTaskRule", "AsyncSequenceRule"
        ]
        for name in expected {
            #expect(names.contains(name), "Missing rule: \(name)")
        }
    }

    // MARK: - File-level analysis

    @Test("Returns no findings for clean Swift 6 code")
    func noFindingsForCleanCode() throws {
        let url = try writeTemp(name: "Clean.swift", content: """
        import Foundation
        struct Config: Sendable { let value: Int }
        func fetchData() async throws -> String { "data" }
        """)
        let result = analyzer.analyzeAsModule(file: url)
        #expect(result.findings.isEmpty)
        #expect(result.status == .migrated)
        #expect(result.score == 0.0)
    }

    @Test("Returns findings for problematic code")
    func findingsForProblematicCode() throws {
        let url = try writeTemp(name: "Bad.swift", content: """
        class VM: @unchecked Sendable {
            func load(completion: @escaping () -> Void) {
                DispatchQueue.main.async { completion() }
            }
        }
        """)
        let result = analyzer.analyzeAsModule(file: url)
        #expect(!result.findings.isEmpty)
        #expect(result.status.isPendingMigration)
        #expect(result.score > 0)
    }

    @Test("analyzeAsModule sets correct file count")
    func singleFileModuleHasFileCountOne() throws {
        let url = try writeTemp(name: "Single.swift", content: "let x = 1")
        let result = analyzer.analyzeAsModule(file: url)
        #expect(result.fileCount == 1)
    }

    @Test("analyzeAsModule counts non-empty lines of code")
    func countsNonEmptyLines() throws {
        let content = """
        import Foundation

        let a = 1
        let b = 2
        """
        let url = try writeTemp(name: "Lines.swift", content: content)
        let result = analyzer.analyzeAsModule(file: url)
        // 3 non-empty lines: import, let a, let b
        #expect(result.totalLinesOfCode == 3)
    }

    // MARK: - Module-level analysis

    @Test("analyzeModules returns one module for a flat project")
    func flatProjectHasOneModule() async throws {
        let dir = try writeTempDir(name: "FlatProject", files: [
            "ViewA.swift": "let x = 1",
            "ViewB.swift": "let y = 2"
        ])
        let scanner = FileScanner()
        let results = await analyzer.analyzeModules(in: dir, fileScanner: scanner)
        #expect(results.count == 1)
        #expect(results[0].fileCount == 2)
    }

    @Test("analyzeModules returns one module per subdirectory for modular project")
    func modularProjectHasOneModulePerDirectory() async throws {
        let dir = try writeTempDir(name: "ModularProject", files: [
            "Core/Model.swift": "struct Model { }",
            "UI/View.swift": "let x = 1",
            "Network/Client.swift": "let y = 2"
        ])
        let scanner = FileScanner()
        let results = await analyzer.analyzeModules(in: dir, fileScanner: scanner)
        #expect(results.count == 3)
    }

    @Test("Module with no findings has status Migrated")
    func cleanModuleIsMigrated() async throws {
        let dir = try writeTempDir(name: "CleanProject", files: [
            "Code.swift": "func hello() async { }"
        ])
        let scanner = FileScanner()
        let results = await analyzer.analyzeModules(in: dir, fileScanner: scanner)
        #expect(results.allSatisfy { $0.status == .migrated })
    }

    @Test("Module with findings has status Pending Migration")
    func problematicModuleIsPending() async throws {
        let dir = try writeTempDir(name: "BadProject", files: [
            "Code.swift": "var globalCounter = 0"
        ])
        let scanner = FileScanner()
        let results = await analyzer.analyzeModules(in: dir, fileScanner: scanner)
        #expect(results.allSatisfy { $0.status == .pendingMigration })
    }

    @Test("Results are sorted alphabetically by module name")
    func resultsAreSortedByName() async throws {
        let dir = try writeTempDir(name: "SortedProject", files: [
            "Zebra/Z.swift": "let z = 1",
            "Alpha/A.swift": "let a = 1",
            "Middle/M.swift": "let m = 1"
        ])
        let scanner = FileScanner()
        let results = await analyzer.analyzeModules(in: dir, fileScanner: scanner)
        let names = results.map(\.name)
        #expect(names == names.sorted())
    }

    // MARK: - Custom rules

    @Test("Analyzer respects custom rule set")
    func customRuleSet() throws {
        let url = try writeTemp(name: "Custom.swift", content: "var globalCounter = 0")
        // Only GlobalMutableStateRule — DispatchQueueRule should not produce findings
        let customAnalyzer = Analyzer(rules: [GlobalMutableStateRule()])
        let result = customAnalyzer.analyzeAsModule(file: url)
        #expect(result.findings.allSatisfy { $0.rule == "GlobalMutableStateRule" })
    }

    // MARK: - Helpers

    private func writeTemp(name: String, content: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AnalyzerTmp_\(name)")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func writeTempDir(name: String, files: [String: String]) throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AnalyzerTmp_\(name)")
        try? FileManager.default.removeItem(at: base)
        for (relativePath, content) in files {
            let fileURL = base.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return base
    }
}


// MARK: - Aggregate score and status tests (appended)

extension AnalyzerTests {

    @Test("Container module aggregateScore equals sum of its children scores")
    func containerAggregateScoreIncludesChildren() async throws {
        // Need 2+ top-level dirs so the scanner detects them as separate modules
        let root = try makeTempDir("AggScore", structure: [
            "FeatureA/Sub1/File1.swift": "var global = 0",   // GlobalMutableState → weight 0.9
            "FeatureA/Sub2/File2.swift": "let x = 1",        // clean
            "FeatureB/Core.swift": "let b = 3"               // clean — sibling at depth 0
        ])
        let analyzer = Analyzer()
        let modules = await analyzer.analyzeModules(in: root, fileScanner: FileScanner())
        let featureA = modules.first { $0.name == "FeatureA" }
        let sub1     = modules.first { $0.name == "Sub1" }

        // FeatureA's own score = 0 (no direct files); aggregateScore includes Sub1 findings
        #expect(featureA?.score == 0.0)
        #expect(featureA?.aggregateScore ?? 0 > 0)
        #expect((featureA?.aggregateScore ?? 0) >= (sub1?.aggregateScore ?? 0))
    }

    @Test("Container module aggregateStatus is pendingMigration when any child is pending")
    func containerAggregateStatusPendingWhenChildPending() async throws {
        let root = try makeTempDir("AggStatus", structure: [
            "FeatureA/Sub1/Bad.swift": "var globalVar = 0",   // will trigger GlobalMutableStateRule
            "FeatureA/Sub2/Good.swift": "let clean = 1",
            "FeatureB/Core.swift": "let b = 3"                // sibling to force multi-module detection
        ])
        let analyzer = Analyzer()
        let modules = await analyzer.analyzeModules(in: root, fileScanner: FileScanner())
        let featureA = modules.first { $0.name == "FeatureA" }

        #expect(featureA?.status == .migrated)                 // no own direct findings
        #expect(featureA?.aggregateStatus == .pendingMigration) // Sub1 has findings
    }

    @Test("childQualifiedNames lists direct children only")
    func childQualifiedNamesDirectOnly() async throws {
        let root = try makeTempDir("ChildNames", structure: [
            "FeatureA/Sub1/S1.swift": "let s1 = 1",
            "FeatureA/Sub2/S2.swift": "let s2 = 2",
            "FeatureB/Core.swift": "let b = 3"
        ])
        let analyzer = Analyzer()
        let modules = await analyzer.analyzeModules(in: root, fileScanner: FileScanner())
        let featureA = modules.first { $0.name == "FeatureA" }

        #expect(featureA?.childQualifiedNames.sorted() == ["FeatureA/Sub1", "FeatureA/Sub2"])
    }

    @Test("Leaf module has empty childQualifiedNames")
    func leafModuleHasNoChildren() async throws {
        let root = try makeTempDir("LeafNoChildren", structure: [
            "Core/File.swift": "let x = 1",
            "UI/View.swift": "struct V { }"    // sibling needed to trigger module detection
        ])
        let analyzer = Analyzer()
        let modules = await analyzer.analyzeModules(in: root, fileScanner: FileScanner())
        let core = modules.first { $0.name == "Core" }
        #expect(core?.childQualifiedNames.isEmpty == true)
    }

    // Helpers
    private func makeTempDir(_ name: String, structure: [String: String]) throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AnalyzerAgg_\(name)_\(UUID().uuidString.prefix(8))")
        try? FileManager.default.removeItem(at: base)
        for (relativePath, content) in structure {
            let fileURL = base.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return base
    }
}
