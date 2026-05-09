import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("SynchronizationPrimitiveRule")
struct SynchronizationPrimitiveRuleTests {

    let rule = SynchronizationPrimitiveRule()

    // MARK: - Detection

    @Test("Detects NSLock via type annotation")
    func detectsNSLockTypeAnnotation() {
        let source = """
        class Service {
            var lock: NSLock = NSLock()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "SynchronizationPrimitiveRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects NSLock via initializer expression")
    func detectsNSLockInitializer() {
        let source = "let myLock = NSLock()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects NSRecursiveLock")
    func detectsNSRecursiveLock() {
        let source = "let recursiveLock = NSRecursiveLock()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects DispatchSemaphore")
    func detectsDispatchSemaphore() {
        let source = "let sem = DispatchSemaphore(value: 1)"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message mentions actor migration")
    func messageMentionsActor() {
        let source = "let lock = NSLock()"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor"))
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
}
