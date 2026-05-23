import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("WithUnsafeCurrentTaskRule")
struct WithUnsafeCurrentTaskRuleTests {

    let rule = WithUnsafeCurrentTaskRule()

    @Test("Detects withUnsafeCurrentTask as .warning")
    func detectsWithUnsafeCurrentTask() {
        let source = """
        func work() {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "WithUnsafeCurrentTaskRule")
        #expect(result[0].severity == .warning)
        #expect(result[0].message.contains("withTaskCancellationHandler"))
    }

    @Test("Detects Task.current member access")
    func detectsTaskCurrent() {
        let source = "let currentTask = Task.current"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].message.contains("Task.current"))
    }

    @Test("Detects Task.current in chained access")
    func detectsTaskCurrentChain() {
        let source = "Task.current?.cancel()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects both deprecated task APIs")
    func detectsBothPatterns() {
        let source = """
        func work() {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            _ = Task.current
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    @Test("Does not flag modern cancellation APIs")
    func ignoresModernAPIs() {
        let source = """
        func work() async throws {
            try await withTaskCancellationHandler {
                try Task.checkCancellation()
            } onCancel: {
                cleanup()
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Reports the correct file name")
    func reportsCorrectFileName() {
        let source = "let task = Task.current"
        let result = findings(from: rule, source: source, file: "Cancellation.swift")
        #expect(result.count == 1)
        #expect(result[0].file == "Cancellation.swift")
    }
}
