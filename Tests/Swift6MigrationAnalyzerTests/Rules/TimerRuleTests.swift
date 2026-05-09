import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - TimerRule

@Suite("TimerRule")
struct TimerRuleTests {

    let rule = TimerRule()

    @Test("Detects Timer.scheduledTimer with block")
    func detectsScheduledTimerBlock() {
        let source = """
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.refresh()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "TimerRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects Timer.scheduledTimer with target/selector")
    func detectsScheduledTimerSelector() {
        let source = """
        Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(tick), userInfo: nil, repeats: false)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects Timer(timeInterval:repeats:block:) initializer")
    func detectsTimerInit() {
        let source = "let t = Timer(timeInterval: 0.5, repeats: true) { _ in }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message mentions Task.sleep or AsyncStream")
    func messageDescribesMigration() {
        let source = "Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("Task.sleep") || result[0].message.contains("AsyncStream"))
    }

    @Test("Does not flag unrelated calls")
    func ignoresUnrelated() {
        let source = "URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
