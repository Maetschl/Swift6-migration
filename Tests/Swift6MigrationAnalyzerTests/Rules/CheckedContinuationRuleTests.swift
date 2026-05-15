import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("CheckedContinuationRule")
struct CheckedContinuationRuleTests {

    let rule = CheckedContinuationRule()

    // MARK: - Detection

    @Test("Detects withUnsafeContinuation as .warning")
    func detectsWithUnsafeContinuation() {
        let source = """
        func fetchData() async -> Data {
            await withUnsafeContinuation { continuation in
                legacyCallback { data in
                    continuation.resume(returning: data)
                }
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "CheckedContinuationRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects withUnsafeThrowingContinuation as .warning")
    func detectsWithUnsafeThrowingContinuation() {
        let source = """
        func fetchData() async throws -> Data {
            try await withUnsafeThrowingContinuation { continuation in
                legacyCallback { result in
                    continuation.resume(with: result)
                }
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "CheckedContinuationRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects multiple unsafe continuation calls")
    func detectsMultipleUnsafeContinuations() {
        let source = """
        func a() async -> Int { await withUnsafeContinuation { $0.resume(returning: 1) } }
        func b() async throws -> Int { try await withUnsafeThrowingContinuation { $0.resume(returning: 2) } }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    // MARK: - Non-detection

    @Test("Does not flag withCheckedContinuation")
    func ignoresWithCheckedContinuation() {
        let source = """
        func fetchData() async -> Data {
            await withCheckedContinuation { continuation in
                legacyCallback { data in
                    continuation.resume(returning: data)
                }
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag withCheckedThrowingContinuation")
    func ignoresWithCheckedThrowingContinuation() {
        let source = """
        func fetchData() async throws -> Data {
            try await withCheckedThrowingContinuation { continuation in
                legacyCallback { result in
                    continuation.resume(with: result)
                }
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag unrelated async code")
    func ignoresUnrelatedAsyncCode() {
        let source = """
        func work() async -> Int {
            async let a = heavyTask()
            return await a
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag withTaskGroup")
    func ignoresWithTaskGroup() {
        let source = "withTaskGroup(of: Int.self) { group in }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    // MARK: - Message quality

    @Test("Finding message names the unsafe API and its safe replacement")
    func findingMessageNamesUnsafeAndSafe() {
        let source = "await withUnsafeContinuation { $0.resume(returning: 0) }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("withUnsafeContinuation"))
        #expect(result[0].message.contains("withCheckedContinuation"))
    }

    @Test("Throwing continuation message names withCheckedThrowingContinuation")
    func throwingMessageNamesCheckedThrowing() {
        let source = "try await withUnsafeThrowingContinuation { $0.resume(returning: 0) }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("withCheckedThrowingContinuation"))
    }

    @Test("Reports the correct file name")
    func reportsCorrectFileName() {
        let source = "await withUnsafeContinuation { $0.resume(returning: 0) }"
        let result = findings(from: rule, source: source, file: "NetworkClient.swift")
        #expect(result[0].file == "NetworkClient.swift")
    }
}
