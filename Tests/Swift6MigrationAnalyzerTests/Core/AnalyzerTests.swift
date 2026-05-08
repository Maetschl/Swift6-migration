import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("Analyzer")
struct AnalyzerTests {

    let analyzer = Analyzer()

    // MARK: - Default rules

    @Test("Analyzer has 16 default Swift 6 rules")
    func hasDefaultRules() {
        #expect(Analyzer.defaultRules.count == 16)
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
            "CombineRule", "ThreadRule"
        ]
        for name in expected {
            #expect(names.contains(name), "Missing rule: \(name)")
        }
    }

    @Test("Quality rules are NOT in defaultRules")
    func qualityRulesNotInDefaults() {
        let names = Analyzer.defaultRules.map(\.name)
        #expect(!names.contains("ForceUnwrapRule"))
        #expect(!names.contains("ForceTryRule"))
    }

    @Test("Quality rules are available via qualityRules")
    func qualityRulesAvailable() {
        let names = Analyzer.qualityRules.map(\.name)
        #expect(names.contains("ForceUnwrapRule"))
        #expect(names.contains("ForceTryRule"))
    }

    @Test("allRules combines default and quality rules")
    func allRulesCombinesBoth() {
        #expect(Analyzer.allRules.count == Analyzer.defaultRules.count + Analyzer.qualityRules.count)
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
        #expect(result.status == .pendingMigration)
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
    func flatProjectHasOneModule() throws {
        let dir = try writeTempDir(name: "FlatProject", files: [
            "ViewA.swift": "let x = 1",
            "ViewB.swift": "let y = 2"
        ])
        let scanner = FileScanner()
        let results = analyzer.analyzeModules(in: dir, fileScanner: scanner)
        #expect(results.count == 1)
        #expect(results[0].fileCount == 2)
    }

    @Test("analyzeModules returns one module per subdirectory for modular project")
    func modularProjectHasOneModulePerDirectory() throws {
        let dir = try writeTempDir(name: "ModularProject", files: [
            "Core/Model.swift": "struct Model { }",
            "UI/View.swift": "let x = 1",
            "Network/Client.swift": "let y = 2"
        ])
        let scanner = FileScanner()
        let results = analyzer.analyzeModules(in: dir, fileScanner: scanner)
        #expect(results.count == 3)
    }

    @Test("Module with no findings has status Migrated")
    func cleanModuleIsMigrated() throws {
        let dir = try writeTempDir(name: "CleanProject", files: [
            "Code.swift": "func hello() async { }"
        ])
        let scanner = FileScanner()
        let results = analyzer.analyzeModules(in: dir, fileScanner: scanner)
        #expect(results.allSatisfy { $0.status == .migrated })
    }

    @Test("Module with findings has status Pending Migration")
    func problematicModuleIsPending() throws {
        let dir = try writeTempDir(name: "BadProject", files: [
            "Code.swift": "var globalCounter = 0"
        ])
        let scanner = FileScanner()
        let results = analyzer.analyzeModules(in: dir, fileScanner: scanner)
        #expect(results.allSatisfy { $0.status == .pendingMigration })
    }

    @Test("Results are sorted alphabetically by module name")
    func resultsAreSortedByName() throws {
        let dir = try writeTempDir(name: "SortedProject", files: [
            "Zebra/Z.swift": "let z = 1",
            "Alpha/A.swift": "let a = 1",
            "Middle/M.swift": "let m = 1"
        ])
        let scanner = FileScanner()
        let results = analyzer.analyzeModules(in: dir, fileScanner: scanner)
        let names = results.map(\.name)
        #expect(names == names.sorted())
    }

    // MARK: - Custom rules

    @Test("Analyzer respects custom rule set")
    func customRuleSet() throws {
        let url = try writeTemp(name: "Custom.swift", content: "let x = optional!")
        // Only ForceUnwrap — ForceTry should not produce findings
        let customAnalyzer = Analyzer(rules: [ForceUnwrapRule()])
        let result = customAnalyzer.analyzeAsModule(file: url)
        #expect(result.findings.allSatisfy { $0.rule == "ForceUnwrapRule" })
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
