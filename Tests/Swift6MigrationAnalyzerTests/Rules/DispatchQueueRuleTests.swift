import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("DispatchQueueRule")
struct DispatchQueueRuleTests {

    let rule = DispatchQueueRule()

    // MARK: - Detection

    @Test("Detects DispatchQueue.main.async")
    func detectsMainAsync() {
        let source = """
        DispatchQueue.main.async {
            print("hello")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "DispatchQueueRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects DispatchQueue.main.asyncAfter")
    func detectsMainAsyncAfter() {
        let source = """
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print("delayed")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects multiple DispatchQueue calls in one file")
    func detectsMultipleOccurrences() {
        let source = """
        func a() { DispatchQueue.main.async { } }
        func b() { DispatchQueue.main.async { } }
        func c() { DispatchQueue.main.async { } }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 3)
    }

    @Test("Detects DispatchQueue.global().async")
    func detectsGlobalAsync() {
        let source = """
        DispatchQueue.global().async {
            print("background work")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    // MARK: - Non-detection

    @Test("Does not flag unrelated function calls")
    func ignoresUnrelatedCalls() {
        let source = "someObject.doWork()"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Reports the correct file name in findings")
    func reportsCorrectFileName() {
        let source = """
        DispatchQueue.main.async {
            print("hello")
        }
        """
        let result = findings(from: rule, source: source, file: "HomeViewModel.swift")
        #expect(result.count == 1)
        #expect(result[0].file == "HomeViewModel.swift")
    }

    @Test("Finding message mentions MainActor or structured concurrency")
    func findingMessageMentionsMigrationPath() {
        let source = """
        DispatchQueue.main.async {
            print("hello")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("MainActor") || result[0].message.contains("concurrency"))
    }
}
