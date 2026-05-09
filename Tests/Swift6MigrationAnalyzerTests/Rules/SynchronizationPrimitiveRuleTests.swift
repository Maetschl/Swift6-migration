import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("SynchronizationPrimitiveRule")
struct SynchronizationPrimitiveRuleTests {

    let rule = SynchronizationPrimitiveRule()

    // MARK: - Detection (.error — Swift 6 compile errors)

    @Test("Detects NSLock via type annotation as .error")
    func detectsNSLockTypeAnnotation() {
        let source = """
        class Service {
            var lock: NSLock = NSLock()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "SynchronizationPrimitiveRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects NSLock via initializer expression as .error")
    func detectsNSLockInitializer() {
        let source = "let myLock = NSLock()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
    }

    @Test("Detects NSRecursiveLock as .error")
    func detectsNSRecursiveLock() {
        let source = "let recursiveLock = NSRecursiveLock()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
    }

    @Test("Detects DispatchSemaphore as .error")
    func detectsDispatchSemaphore() {
        let source = "let sem = DispatchSemaphore(value: 1)"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
    }

    @Test("Detects NSCondition as .error")
    func detectsNSCondition() {
        let source = "var cond: NSCondition"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
    }

    @Test("Finding message mentions actor migration")
    func messageMentionsActor() {
        let source = "let lock = NSLock()"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor"))
    }

    @Test("Finding message mentions compile error")
    func messageMentionsCompileError() {
        let source = "let lock = NSLock()"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.lowercased().contains("compile error") || result[0].message.lowercased().contains("data race"))
    }

    // MARK: - Non-detection

    @Test("Does not flag unrelated type usage")
    func ignoresUnrelatedTypes() {
        let source = """
        let queue = OperationQueue()
        let name = "Hello"
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag actor declaration")
    func ignoresActor() {
        let source = "actor DataStore { var items: [String] = [] }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
