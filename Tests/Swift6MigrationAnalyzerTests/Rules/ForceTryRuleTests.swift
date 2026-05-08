import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("ForceTryRule")
struct ForceTryRuleTests {

    let rule = ForceTryRule()

    // MARK: - Detection

    @Test("Detects try!")
    func detectsForceTry() {
        let source = "let data = try! Data(contentsOf: url)"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "ForceTryRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects try! in a closure")
    func detectsForceTryInClosure() {
        let source = """
        let result = items.map { item in
            try! process(item)
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects multiple try! expressions")
    func detectsMultiple() {
        let source = """
        let a = try! decode(x)
        let b = try! decode(y)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    // MARK: - Non-detection

    @Test("Does not flag regular try")
    func ignoresRegularTry() {
        let source = """
        do {
            let data = try Data(contentsOf: url)
        } catch {
            print(error)
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag try?")
    func ignoresTryOptional() {
        let source = "let data = try? Data(contentsOf: url)"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("ForceTry has error severity (higher than ForceUnwrap warning)")
    func hasCriticalSeverity() {
        let source = "let x = try! something()"
        let result = findings(from: rule, source: source)
        #expect(result[0].severity == .error)
    }

    @Test("Reports correct line number")
    func reportsCorrectLine() {
        let source = """
        import Foundation
        let x = 1
        let data = try! Data(contentsOf: someURL)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].line == 3)
    }
}
