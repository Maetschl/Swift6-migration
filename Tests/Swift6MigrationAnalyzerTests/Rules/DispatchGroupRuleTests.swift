import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - DispatchGroupRule

@Suite("DispatchGroupRule")
struct DispatchGroupRuleTests {

    let rule = DispatchGroupRule()

    @Test("Detects DispatchGroup() initializer in variable")
    func detectsDispatchGroupInit() {
        let source = "let group = DispatchGroup()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "DispatchGroupRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects DispatchGroup via type annotation")
    func detectsDispatchGroupTypeAnnotation() {
        let source = """
        class Loader {
            var group: DispatchGroup = DispatchGroup()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
    }

    @Test("Finding message mentions withTaskGroup or async let")
    func messageDescribesMigration() {
        let source = "let g = DispatchGroup()"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("withTaskGroup") || result[0].message.contains("async let"))
    }

    @Test("Does not flag unrelated DispatchQueue usage")
    func ignoresDispatchQueue() {
        let source = "DispatchQueue.main.async { print(\"hi\") }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
