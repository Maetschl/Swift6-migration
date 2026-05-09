import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("NotificationCenterRule")
struct NotificationCenterRuleTests {

    let rule = NotificationCenterRule()

    // MARK: - Detection

    @Test("Detects NotificationCenter.default.addObserver")
    func detectsAddObserver() {
        let source = """
        NotificationCenter.default.addObserver(self, selector: #selector(handle), name: .NSManagedObjectContextDidSave, object: nil)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "NotificationCenterRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects NotificationCenter.default.post")
    func detectsPost() {
        let source = """
        NotificationCenter.default.post(name: .init("MyEvent"), object: nil)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message mentions actor isolation or async")
    func messageDescribesFix() {
        let source = "NotificationCenter.default.addObserver(self, selector: #selector(h), name: .NSManagedObjectContextDidSave, object: nil)"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor") || result[0].message.contains("async") || result[0].message.contains("MainActor"))
    }

    // MARK: - Non-detection

    @Test("Does not flag unrelated function calls")
    func ignoresUnrelatedCalls() {
        let source = "URLSession.shared.dataTask(with: url) { _, _, _ in }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
