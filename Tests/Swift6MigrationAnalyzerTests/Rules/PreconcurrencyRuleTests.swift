import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - PreconcurrencyRule

@Suite("PreconcurrencyRule")
struct PreconcurrencyRuleTests {

    let rule = PreconcurrencyRule()

    @Test("Detects @preconcurrency import")
    func detectsPreconcurrencyImport() {
        let source = "@preconcurrency import SomeOldModule"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "PreconcurrencyRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects multiple @preconcurrency imports")
    func detectsMultipleImports() {
        let source = """
        @preconcurrency import ModuleA
        import Foundation
        @preconcurrency import ModuleB
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    @Test("Finding message mentions the imported module name")
    func messageIncludesModuleName() {
        let source = "@preconcurrency import LegacyNetworking"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("LegacyNetworking"))
    }

    @Test("Does not flag regular import without @preconcurrency")
    func ignoresRegularImport() {
        let source = "import Foundation"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
