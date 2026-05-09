import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - ThreadRule

@Suite("ThreadRule")
struct ThreadRuleTests {

    let rule = ThreadRule()

    @Test("Detects Thread.detachNewThread")
    func detectsDetachNewThread() {
        let source = "Thread.detachNewThread { self.work() }"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "ThreadRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects Thread(block:) initializer")
    func detectsThreadBlockInit() {
        let source = "let t = Thread { self.process() }"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
    }

    @Test("Detects Thread.isMainThread member access")
    func detectsIsMainThread() {
        let source = """
        if Thread.isMainThread {
            updateUI()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result.contains { $0.message.contains("isMainThread") })
    }

    @Test("Detects Thread.main member access")
    func detectsThreadMain() {
        let source = "let t = Thread.main"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
    }

    @Test("Finding message mentions actor isolation")
    func messageDescribesFix() {
        let source = "Thread.detachNewThread { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor") || result[0].message.contains("MainActor"))
    }
}
