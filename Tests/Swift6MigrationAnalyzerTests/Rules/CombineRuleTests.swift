import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - CombineRule

@Suite("CombineRule")
struct CombineRuleTests {

    let rule = CombineRule()

    // MARK: - Detection (.error — Swift 6 compile errors)

    @Test("Detects .sink closure as .error")
    func detectsSink() {
        let source = """
        publisher
            .sink { value in self.label = value }
            .store(in: &cancellables)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result.contains { $0.rule == "CombineRule" && $0.message.contains("sink") })
        #expect(result.contains { $0.severity == .error })
    }

    @Test("Detects assign(to:on:) as .error")
    func detectsAssign() {
        let source = "publisher.assign(to: \\.title, on: self)"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "CombineRule")
        #expect(result[0].severity == .error)
    }

    // MARK: - Detection (.warning — non-blocking recommendation)

    @Test("Detects AnyCancellable stored property as .warning")
    func detectsAnyCancellable() {
        let source = """
        class ViewModel {
            var cancellable: AnyCancellable?
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "CombineRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects Set<AnyCancellable> stored property as .warning")
    func detectsAnyCancellableSet() {
        let source = """
        class VM {
            var cancellables: Set<AnyCancellable> = []
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .warning)
    }

    // MARK: - Non-detection

    @Test("Does not flag plain property unrelated to Combine")
    func ignoresUnrelated() {
        let source = "var name: String = \"\""
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag async sequence usage")
    func ignoresAsyncSequence() {
        let source = "for await value in publisher.values { print(value) }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
