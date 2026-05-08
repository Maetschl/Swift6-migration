import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("UncheckedSendableRule")
struct UncheckedSendableRuleTests {

    let rule = UncheckedSendableRule()

    // MARK: - Detection

    @Test("Detects @unchecked Sendable on a class")
    func detectsOnClass() {
        let source = """
        class MyViewModel: @unchecked Sendable {
            var state: String = ""
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "UncheckedSendableRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects @unchecked Sendable on a struct")
    func detectsOnStruct() {
        let source = "struct Config: @unchecked Sendable { var value: Any }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects @unchecked Sendable alongside other conformances")
    func detectsAlongsideOtherConformances() {
        let source = "class MyClass: NSObject, @unchecked Sendable { }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects multiple @unchecked Sendable in the same file")
    func detectsMultiple() {
        let source = """
        class A: @unchecked Sendable { }
        class B: @unchecked Sendable { }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    // MARK: - Non-detection

    @Test("Does not flag plain Sendable conformance")
    func ignoresPlainSendable() {
        let source = """
        struct SafeValue: Sendable {
            let value: Int
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag unrelated protocol conformances")
    func ignoresUnrelatedConformances() {
        let source = "class VC: UIViewController, Equatable { }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Reports error severity (highest weight in table)")
    func hasErrorSeverity() {
        let source = "class Bad: @unchecked Sendable { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].severity == .error)
    }

    @Test("Reports correct line number")
    func reportsCorrectLine() {
        let source = """
        import Foundation

        class MyService: @unchecked Sendable {
            var lock = NSLock()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].line == 3)
    }
}
