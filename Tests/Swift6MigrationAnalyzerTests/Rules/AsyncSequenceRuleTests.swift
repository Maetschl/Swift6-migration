import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("AsyncSequenceRule")
struct AsyncSequenceRuleTests {

    let rule = AsyncSequenceRule()

    @Test("Detects PassthroughSubject type usage as .warning")
    func detectsPassthroughSubjectType() {
        let source = "var subject: PassthroughSubject<Int, Never>?"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "AsyncSequenceRule")
        #expect(result[0].severity == .warning)
        #expect(result[0].message.contains("AsyncStream"))
    }

    @Test("Detects CurrentValueSubject initialization")
    func detectsCurrentValueSubjectInit() {
        let source = "let subject = CurrentValueSubject<Int, Never>(0)"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].message.contains("CurrentValueSubject"))
    }

    @Test("Deduplicates type and initializer on the same line")
    func deduplicatesSameLineTypeAndInit() {
        let source = "let subject: PassthroughSubject<Int, Never> = PassthroughSubject<Int, Never>()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects both Combine subject variants")
    func detectsBothSubjectKinds() {
        let source = """
        let first = PassthroughSubject<Int, Never>()
        let second = CurrentValueSubject<Int, Never>(0)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    @Test("Does not flag AsyncStream usage")
    func ignoresAsyncStream() {
        let source = "let (stream, continuation) = AsyncStream.makeStream(of: Int.self)"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag unrelated generic types")
    func ignoresUnrelatedTypes() {
        let source = "let numbers: Array<Int> = [1, 2, 3]"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
