import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - NonisolatedUnsafeRule

@Suite("NonisolatedUnsafeRule")
struct NonisolatedUnsafeRuleTests {

    let rule = NonisolatedUnsafeRule()

    @Test("Detects nonisolated(unsafe) on stored property")
    func detectsNonisolatedUnsafe() {
        let source = """
        class Cache {
            nonisolated(unsafe) var shared: [String: Any] = [:]
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "NonisolatedUnsafeRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects nonisolated(unsafe) at file scope")
    func detectsAtFileScope() {
        let source = "nonisolated(unsafe) var globalCache: [String: Any] = [:]"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message mentions audit and data races")
    func messageDescribesRisk() {
        let source = "nonisolated(unsafe) var x = 0"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("audit") || result[0].message.contains("data race"))
    }

    @Test("Does not flag regular nonisolated computed property")
    func ignoresNonisolatedComputedProperty() {
        let source = """
        actor MyActor {
            nonisolated var description: String { "MyActor" }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag regular stored var without modifier")
    func ignoresRegularVar() {
        let source = "var counter = 0"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
