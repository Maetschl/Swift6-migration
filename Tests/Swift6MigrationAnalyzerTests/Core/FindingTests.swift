import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("Finding")
struct FindingTests {

    // MARK: - location property

    @Test("location returns 'file:line' string")
    func locationFormatIsFileColon() {
        let f = Finding(file: "Sources/App/Foo.swift", line: 42, severity: .error, rule: "SomeRule", message: "msg")
        #expect(f.location == "Sources/App/Foo.swift:42")
    }

    @Test("location uses line number, not column")
    func locationDoesNotIncludeColumn() {
        let f = Finding(file: "Bar.swift", line: 7, column: 15, severity: .warning, rule: "ARule", message: "")
        #expect(f.location == "Bar.swift:7")
        #expect(!f.location.contains("15"))
    }

    // MARK: - Default column

    @Test("Default column is 0 when not supplied")
    func defaultColumnIsZero() {
        let f = Finding(file: "X.swift", line: 1, severity: .warning, rule: "R", message: "m")
        #expect(f.column == 0)
    }

    // MARK: - Severity stored correctly

    @Test("Severity .error is stored correctly")
    func severityErrorStored() {
        let f = Finding(file: "F.swift", line: 1, severity: .error, rule: "R", message: "m")
        #expect(f.severity == .error)
    }

    @Test("Severity .warning is stored correctly")
    func severityWarningStored() {
        let f = Finding(file: "F.swift", line: 1, severity: .warning, rule: "R", message: "m")
        #expect(f.severity == .warning)
    }

    @Test("Severity .info is stored correctly")
    func severityInfoStored() {
        let f = Finding(file: "F.swift", line: 1, severity: .info, rule: "R", message: "m")
        #expect(f.severity == .info)
    }

    // MARK: - Codable round-trip

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = Finding(file: "Networking/Client.swift", line: 99, column: 5,
                               severity: .error, rule: "DispatchQueueRule",
                               message: "Replace with @MainActor")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Finding.self, from: data)
        #expect(decoded.file     == original.file)
        #expect(decoded.line     == original.line)
        #expect(decoded.column   == original.column)
        #expect(decoded.severity == original.severity)
        #expect(decoded.rule     == original.rule)
        #expect(decoded.message  == original.message)
    }

    @Test("Codable round-trip for .warning severity")
    func codableRoundTripWarning() throws {
        let original = Finding(file: "UI/View.swift", line: 3, severity: .warning,
                               rule: "ObservableObjectRule", message: "Migrate to @Observable")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Finding.self, from: data)
        #expect(decoded.severity == .warning)
        #expect(decoded.rule == "ObservableObjectRule")
    }

    @Test("Severity encodes to its rawValue string")
    func severityEncodesAsString() throws {
        let f = Finding(file: "F.swift", line: 1, severity: .error, rule: "R", message: "")
        let data = try JSONEncoder().encode(f)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["severity"] as? String == "error")
    }

    // MARK: - Array of findings Codable

    @Test("Array of findings encodes and decodes correctly")
    func arrayOfFindingsCodable() throws {
        let findings = [
            Finding(file: "A.swift", line: 1, severity: .error,   rule: "RuleA", message: "error msg"),
            Finding(file: "B.swift", line: 2, severity: .warning, rule: "RuleB", message: "warning msg")
        ]
        let data = try JSONEncoder().encode(findings)
        let decoded = try JSONDecoder().decode([Finding].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0].rule == "RuleA")
        #expect(decoded[1].severity == .warning)
    }
}
