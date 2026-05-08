import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("ForceUnwrapRule")
struct ForceUnwrapRuleTests {

    let rule = ForceUnwrapRule()

    // MARK: - Detection

    @Test("Detects simple force unwrap")
    func detectsSimpleForceUnwrap() {
        let source = "let x = someOptional!"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "ForceUnwrapRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects force unwrap on function result")
    func detectsForceUnwrapOnCall() {
        let source = "let url = URL(string: \"https://example.com\")!"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects force unwrap in chain")
    func detectsForceUnwrapInChain() {
        let source = "let name = dict[\"key\"]!.trimmingCharacters(in: .whitespaces)"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects multiple force unwraps")
    func detectsMultiple() {
        let source = """
        let a = x!
        let b = y!
        let c = z!
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 3)
    }

    // MARK: - Non-detection

    @Test("Does not flag optional chaining")
    func ignoresOptionalChaining() {
        let source = "let x = someOptional?.value"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag nil coalescing")
    func ignoresNilCoalescing() {
        let source = "let x = someOptional ?? defaultValue"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag guard let")
    func ignoresGuardLet() {
        let source = """
        guard let value = someOptional else { return }
        print(value)
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Reports correct line number")
    func reportsCorrectLine() {
        let source = """
        let a = 1
        let b = 2
        let c = optional!
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].line == 3)
    }
}
