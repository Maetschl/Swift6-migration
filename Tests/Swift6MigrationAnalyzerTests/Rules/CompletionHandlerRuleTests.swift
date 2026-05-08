import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("CompletionHandlerRule")
struct CompletionHandlerRuleTests {

    let rule = CompletionHandlerRule()

    // MARK: - Detection

    @Test("Detects completion: @escaping parameter")
    func detectsCompletionParam() {
        let source = """
        func fetchData(completion: @escaping (Result<String, Error>) -> Void) {
            completion(.success("done"))
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "CompletionHandlerRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects handler: @escaping parameter")
    func detectsHandlerParam() {
        let source = """
        func load(handler: @escaping (Data?) -> Void) { }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects callback: @escaping parameter")
    func detectsCallbackParam() {
        let source = """
        func submit(callback: @escaping () -> Void) { }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects multiple completion parameters")
    func detectsMultiple() {
        let source = """
        func a(completion: @escaping () -> Void) { }
        func b(handler: @escaping (Int) -> Void) { }
        func c(callback: @escaping (String) -> Void) { }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 3)
    }

    @Test("Finding message mentions the parameter name")
    func messageContainsParamName() {
        let source = "func go(completion: @escaping () -> Void) { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("completion"))
    }

    // MARK: - Non-detection

    @Test("Does not flag non-escaping closure parameter")
    func ignoresNonEscaping() {
        let source = """
        func run(block: () -> Void) { block() }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag @escaping parameter with unrelated name")
    func ignoresUnrelatedEscapingParam() {
        let source = """
        func transform(mapper: @escaping (Int) -> String) -> [String] { [] }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag async functions")
    func ignoresAsyncFunction() {
        let source = """
        func fetchData() async throws -> String { return "data" }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
