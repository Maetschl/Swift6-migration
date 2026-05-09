import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("OperationQueueMainRule")
struct OperationQueueMainRuleTests {

    let rule = OperationQueueMainRule()

    // MARK: - Detection

    @Test("Detects OperationQueue.main.addOperation")
    func detectsAddOperation() {
        let source = "OperationQueue.main.addOperation { print(\"done\") }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "OperationQueueMainRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects OperationQueue.main in chained calls")
    func detectsChainedCall() {
        let source = """
        OperationQueue.main.addOperation(BlockOperation {
            self.tableView.reloadData()
        })
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
    }

    @Test("Finding message mentions @MainActor")
    func messagesMentionMainActor() {
        let source = "OperationQueue.main.addOperation { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("MainActor") || result[0].message.contains("concurrency"))
    }

    // MARK: - Non-detection

    @Test("Does not flag OperationQueue() without main")
    func ignoresBackgroundQueue() {
        let source = """
        let queue = OperationQueue()
        queue.addOperation { print("bg") }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
