import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("TaskDetachedRule")
struct TaskDetachedRuleTests {

    let rule = TaskDetachedRule()

    // MARK: - Detection

    @Test("Detects Task.detached as .error")
    func detectsTaskDetached() {
        let source = """
        Task.detached {
            print("work")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "TaskDetachedRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects Task.detached with priority")
    func detectsTaskDetachedWithPriority() {
        let source = "Task.detached(priority: .background) { print(\"work\") }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects multiple Task.detached calls in separate functions")
    func detectsMultiple() {
        // One-liner functions avoid top-level and multi-line closure parsing quirks
        let source = """
        func runA() { Task.detached { } }
        func runB() { Task.detached { } }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    // MARK: - Non-detection

    @Test("Does not flag plain Task { }")
    func ignoresPlainTask() {
        let source = """
        Task {
            print("work")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag unrelated async code")
    func ignoresAsyncCode() {
        let source = "withTaskGroup(of: Int.self) { _ in }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Reports the correct file name in findings")
    func reportsCorrectFileName() {
        let source = """
        Task.detached {
            print("work")
        }
        """
        let result = findings(from: rule, source: source, file: "BackgroundService.swift")
        #expect(result.count == 1)
        #expect(result[0].file == "BackgroundService.swift")
    }

    @Test("Finding message mentions actor isolation or structured concurrency")
    func findingMessageMentionsMigrationPath() {
        let source = """
        Task.detached {
            print("work")
        }
        """
        let result = findings(from: rule, source: source)
        #expect(
            result[0].message.contains("actor") ||
            result[0].message.contains("isolation") ||
            result[0].message.contains("concurrency")
        )
    }
}
