import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - ThreadRule

@Suite("ThreadRule")
struct ThreadRuleTests {

    let rule = ThreadRule()

    // MARK: - Detection (.error — compile errors)

    @Test("Detects Thread.detachNewThread as .error")
    func detectsDetachNewThread() {
        let source = "Thread.detachNewThread { self.work() }"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "ThreadRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects Thread(block:) initializer as .error")
    func detectsThreadBlockInit() {
        let source = "let t = Thread { self.process() }"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].severity == .error)
    }

    @Test("detachNewThread message mentions actor isolation and compile error")
    func messageDescribesFix() {
        let source = "Thread.detachNewThread { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor") || result[0].message.contains("MainActor"))
    }

    // MARK: - Detection (.warning — runtime checks)

    @Test("Detects Thread.isMainThread as .warning")
    func detectsIsMainThread() {
        let source = """
        if Thread.isMainThread {
            updateUI()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result.contains { $0.message.contains("isMainThread") })
        #expect(result.contains { $0.severity == .warning })
    }

    @Test("Detects Thread.main as .warning")
    func detectsThreadMain() {
        let source = "let t = Thread.main"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].severity == .warning)
    }

    @Test("Detects Thread.current as .warning")
    func detectsThreadCurrent() {
        let source = "let c = Thread.current"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].severity == .warning)
    }

    // MARK: - Non-detection

    @Test("Does not flag Task-based concurrency")
    func ignoresTask() {
        let source = "Task { await doWork() }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag actor declaration")
    func ignoresActorDecl() {
        let source = "actor Worker { func run() {} }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
