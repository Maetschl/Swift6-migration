import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - CombineRule

@Suite("CombineRule")
struct CombineRuleTests {

    let rule = CombineRule()

    @Test("Detects .sink closure")
    func detectsSink() {
        let source = """
        publisher
            .sink { value in self.label = value }
            .store(in: &cancellables)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result.contains { $0.rule == "CombineRule" && $0.message.contains("sink") })
    }

    @Test("Detects assign(to:on:)")
    func detectsAssign() {
        let source = "publisher.assign(to: \\.title, on: self)"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "CombineRule")
    }

    @Test("Detects AnyCancellable stored property")
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

    @Test("Detects Set<AnyCancellable> stored property")
    func detectsAnyCancellableSet() {
        let source = """
        class VM {
            var cancellables: Set<AnyCancellable> = []
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Does not flag plain property unrelated to Combine")
    func ignoresUnrelated() {
        let source = "var name: String = \"\""
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
