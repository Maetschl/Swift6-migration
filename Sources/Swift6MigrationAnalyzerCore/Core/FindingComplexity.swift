/// Complexity weight table for each rule.
/// Weight ranges from 0.1 (trivial fix) to 1.0 (deep architectural change).
/// Migration score for a set of findings = SUM(finding × complexity weight).
public struct FindingComplexity: Sendable {

    // MARK: - Weight Table

    /// Full complexity weight table keyed by rule name.
    /// Only Swift 6 concurrency migration rules are in the default table.
    public static let weightTable: [(rule: String, weight: Double, rationale: String)] = [
        // Score 1.0 — Requires deep architectural audit
        ("UncheckedSendableRule",       1.0, "Bypasses Swift 6 concurrency checks; full thread-safety audit required"),
        ("NonisolatedUnsafeRule",       0.9, "Property-level concurrency bypass; all access sites must be audited for data races"),
        ("GlobalMutableStateRule",      0.9, "Non-isolated global mutable state is a compile error in Swift 6; requires actor isolation or redesign"),
        // Score 0.7–0.8 — Significant refactor
        ("SynchronizationPrimitiveRule",0.8, "Manual lock-based synchronization must be replaced with actors for Swift 6 safety"),
        ("ThreadRule",                  0.7, "Direct Thread API bypasses actor isolation; must be replaced with actors or structured concurrency"),
        ("DispatchQueueRule",           0.7, "Requires adopting @MainActor, structured concurrency, or Swift actor patterns"),
        ("OperationQueueMainRule",      0.7, "OperationQueue.main usage must be replaced with @MainActor isolation"),
        // Score 0.5–0.6 — Medium refactor
        ("CombineRule",                 0.6, "Combine threading model does not integrate with Swift 6 actor isolation; migrate to async sequences"),
        ("DispatchGroupRule",           0.6, "DispatchGroup must be replaced with async let or withTaskGroup for structured concurrency"),
        ("TaskDetachedRule",            0.6, "Actor isolation must be carefully analyzed when using Task.detached"),
        ("MainActorMissingRule",        0.6, "UIKit/AppKit subclass must explicitly declare @MainActor isolation"),
        ("TimerRule",                   0.5, "Callback-based Timer must be replaced with Task.sleep or AsyncStream-based timer"),
        ("ObservableObjectRule",        0.5, "Migrate ObservableObject + @Published to the @Observable macro"),
        ("CompletionHandlerRule",       0.5, "Full async/await refactor of the call-site and all callers required"),
        // Score 0.3–0.4 — Lower effort
        ("PreconcurrencyRule",          0.4, "@preconcurrency suppresses Swift 6 warnings; each annotation must be audited and removed"),
        ("NotificationCenterRule",      0.4, "Notification observer closures need explicit actor isolation context"),
    ]

    /// Complexity weights for optional legacy code-quality rules (not Swift 6 specific).
    public static let legacyWeightTable: [(rule: String, weight: Double, rationale: String)] = [
        ("ForceTryRule",   0.8, "Error handling must be restructured with try/catch or try?"),
        ("ForceUnwrapRule",0.3, "Straightforward replacement with optional binding"),
    ]

    /// Default weight for unknown rules.
    public static let defaultWeight: Double = 0.5

    // MARK: - Lookup

    public static func weight(for rule: String) -> Double {
        weightTable.first { $0.rule == rule }?.weight
            ?? legacyWeightTable.first { $0.rule == rule }?.weight
            ?? defaultWeight
    }

    // MARK: - Score Calculation
    // Score = SUM(finding × complexity weight)

    public static func score(for findings: [Finding]) -> Double {
        findings.reduce(0.0) { accumulated, finding in
            accumulated + weight(for: finding.rule)
        }
    }
}
