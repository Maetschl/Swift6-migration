import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("DispatchQueueRule")
struct DispatchQueueRuleTests {

    let rule = DispatchQueueRule()

    // MARK: - Detection (.error — Swift 6 compile errors)

    @Test("Detects DispatchQueue.main.async as .error")
    func detectsMainAsync() {
        let source = """
        DispatchQueue.main.async {
            print("hello")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "DispatchQueueRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects DispatchQueue.main.asyncAfter as .error")
    func detectsMainAsyncAfter() {
        let source = """
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print("delayed")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
    }

    @Test("Detects DispatchQueue.global().async as .error")
    func detectsGlobalAsync() {
        let source = """
        DispatchQueue.global().async {
            print("background work")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
    }

    @Test("Detects DispatchQueue.sync as .error")
    func detectsSync() {
        let source = """
        DispatchQueue.main.sync {
            print("sync")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
    }

    @Test("Detects manual DispatchQueue creation as .error")
    func detectsManualCreation() {
        let source = """
        let queue = DispatchQueue(label: "com.app.bg")
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
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

    @Test("main.async message mentions MainActor")
    func mainAsyncMessageMentionsMainActor() {
        let source = "DispatchQueue.main.async { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("MainActor"))
    }

    @Test("global().async message mentions Task or structured concurrency")
    func globalAsyncMessageMentionsTask() {
        let source = "DispatchQueue.global().async { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("Task") || result[0].message.contains("concurrency"))
    }

    @Test("Reports the correct file name in findings")
    func reportsCorrectFileName() {
        let source = "DispatchQueue.main.async { print(\"hello\") }"
        let result = findings(from: rule, source: source, file: "HomeViewModel.swift")
        #expect(result.count == 1)
        #expect(result[0].file == "HomeViewModel.swift")
    }

    // MARK: - Non-detection

    @Test("Does not flag unrelated function calls")
    func ignoresUnrelatedCalls() {
        let source = "someObject.doWork()"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag Task-based concurrency")
    func ignoresTaskConcurrency() {
        let source = """
        Task { @MainActor in
            print("main actor")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
