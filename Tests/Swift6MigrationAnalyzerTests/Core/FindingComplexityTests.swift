import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("FindingComplexity")
struct FindingComplexityTests {

    // MARK: - Weight table validity

    @Test("All rules in the table have weights between 0.1 and 1.0")
    func weightsAreInValidRange() {
        for entry in FindingComplexity.weightTable {
            #expect(entry.weight >= 0.1, "Rule \(entry.rule) weight \(entry.weight) is below 0.1")
            #expect(entry.weight <= 1.0, "Rule \(entry.rule) weight \(entry.weight) exceeds 1.0")
        }
    }

    @Test("Table contains all 17 Swift 6 concurrency rules")
    func tableContainsAllKnownRules() {
        let ruleNames = FindingComplexity.weightTable.map(\.rule)
        let expected = [
            "GlobalMutableStateRule", "NonisolatedUnsafeRule",
            "UncheckedSendableRule", "SynchronizationPrimitiveRule",
            "ThreadRule", "DispatchQueueRule", "OperationQueueMainRule",
            "CombineRule", "DispatchGroupRule", "TaskDetachedRule",
            "MainActorRunRule", "MainActorMissingRule", "TimerRule",
            "ObservableObjectRule", "CompletionHandlerRule",
            "PreconcurrencyRule", "NotificationCenterRule"
        ]
        for name in expected {
            #expect(ruleNames.contains(name), "Missing rule in weight table: \(name)")
        }
    }

    // MARK: - Specific weights

    @Test("GlobalMutableStateRule has weight 0.9 (second highest)")
    func globalMutableStateWeight() {
        #expect(FindingComplexity.weight(for: "GlobalMutableStateRule") == 0.9)
    }

    @Test("UncheckedSendableRule has the highest weight (1.0)")
    func uncheckedSendableHasHighestWeight() {
        #expect(FindingComplexity.weight(for: "UncheckedSendableRule") == 1.0)
    }

    @Test("NotificationCenterRule has the lowest known weight (0.4)")
    func notificationCenterHasLowestWeight() {
        #expect(FindingComplexity.weight(for: "NotificationCenterRule") == 0.4)
    }

    @Test("Unknown rule returns default weight 0.5")
    func unknownRuleReturnsDefault() {
        #expect(FindingComplexity.weight(for: "SomeUnknownRule") == FindingComplexity.defaultWeight)
    }

    // MARK: - Score calculation: SUM(finding × complexity weight)

    @Test("Score is 0 for empty findings")
    func scoreIsZeroForEmpty() {
        #expect(FindingComplexity.score(for: []) == 0.0)
    }

    @Test("Score equals weight for a single finding")
    func scoreForSingleFinding() {
        let finding = Finding(
            file: "Test.swift", line: 1, severity: .error,
            rule: "UncheckedSendableRule", message: "test"
        )
        #expect(FindingComplexity.score(for: [finding]) == 1.0)
    }

    @Test("Score sums correctly across multiple findings of the same rule")
    func scoreForMultipleSameRule() {
        let findings = (0..<3).map { i in
            Finding(file: "Test.swift", line: i, severity: .warning,
                    rule: "NotificationCenterRule", message: "test")
        }
        // 3 × 0.4 = 1.2
        #expect(abs(FindingComplexity.score(for: findings) - 1.2) < 0.0001)
    }

    @Test("Score sums correctly across findings of different rules")
    func scoreForMixedRules() {
        let findings = [
            Finding(file: "T.swift", line: 1, severity: .error,   rule: "UncheckedSendableRule",  message: ""),  // 1.0
            Finding(file: "T.swift", line: 2, severity: .error,   rule: "GlobalMutableStateRule", message: ""),  // 0.9
            Finding(file: "T.swift", line: 3, severity: .warning, rule: "NotificationCenterRule", message: "")  // 0.4
        ]
        // 1.0 + 0.9 + 0.4 = 2.3
        let score = FindingComplexity.score(for: findings)
        #expect(abs(score - 2.3) < 0.0001)
    }

    @Test("Higher-weight rules contribute more to score than lower-weight ones")
    func higherWeightContributesMore() {
        let high = Finding(file: "T.swift", line: 1, severity: .error,   rule: "UncheckedSendableRule",  message: "")
        let low  = Finding(file: "T.swift", line: 2, severity: .warning, rule: "NotificationCenterRule", message: "")
        #expect(FindingComplexity.score(for: [high]) > FindingComplexity.score(for: [low]))
    }

}
