/// Complexity weight table and scoring utilities for Swift 6 migration findings.
/// Weight ranges from 0.1 (trivial fix) to 1.0 (deep architectural change).
/// Migration score for a set of findings = SUM(finding × complexity weight).
public struct FindingComplexity: Sendable {

    // MARK: - Weight Table

    /// Full complexity weight table keyed by rule name.
    /// Only Swift 6 concurrency migration rules are in the default table.
    public static let weightTable: [(rule: String, weight: Double, rationale: String)] = [
        // Score 0.9–1.0 — Deep architectural audit required (all .error)
        ("UncheckedSendableRule",        1.0, "Bypasses Swift 6 Sendable checking entirely; full thread-safety audit required"),
        ("NonisolatedUnsafeRule",        0.9, "Property-level concurrency bypass; all access sites must be audited for data races"),
        ("GlobalMutableStateRule",       0.9, "Non-isolated global mutable state is a Swift 6 compile error; requires actor isolation or redesign"),
        // Score 0.7–0.8 — Significant refactor required (all .error)
        ("SynchronizationPrimitiveRule", 0.8, "Manual lock-based synchronization violates Swift 6 actor isolation — compile error; replace with actor or Mutex<T>"),
        ("ThreadRule",                   0.7, "Direct Thread API creates untracked threads outside actor isolation — Swift 6 compile error; replace with actor or Task"),
        ("DispatchQueueRule",            0.7, "DispatchQueue.async/.sync captures self across actor boundaries — Swift 6 compile error; adopt @MainActor or Task"),
        ("OperationQueueMainRule",       0.7, "OperationQueue.main must be replaced with @MainActor isolation"),
        // Score 0.5–0.6 — Medium refactor required (all .error)
        ("CombineRule",                  0.6, ".sink/.assign capture self across actor boundaries — Swift 6 compile error; migrate to async sequences"),
        ("DispatchGroupRule",            0.6, "DispatchGroup callbacks execute on untracked threads — Swift 6 compile error; use async let or withTaskGroup"),
        ("TaskDetachedRule",             0.6, "Task.detached drops actor context, sending non-Sendable values — Swift 6 compile error; use Task { }"),
        ("MainActorRunRule",             0.7, "Sending non-Sendable self into await MainActor.run from non-isolated async context — Swift 6 compile error; add @MainActor or Sendable"),
        ("MainActorMissingRule",         0.6, "UIKit/AppKit subclass should explicitly declare @MainActor isolation (warning — not a compile error)"),
        ("TimerRule",                    0.5, "Callback-based Timer fires on RunLoop thread outside actor isolation (warning — recommendation)"),
        ("ObservableObjectRule",         0.5, "Migrate ObservableObject + @Published to the @Observable macro (warning — recommendation)"),
        ("CompletionHandlerRule",        0.5, "Full async/await refactor of the call-site and all callers required (warning — recommendation)"),
        // Score 0.3–0.4 — Lower effort (all .warning)
        ("PreconcurrencyRule",           0.4, "@preconcurrency suppresses Swift 6 warnings; each annotation must be audited and removed"),
        ("NotificationCenterRule",       0.4, "Notification observer closures need explicit actor isolation context"),
        ("CheckedContinuationRule",      0.5, "withUnsafeContinuation skips resume-count validation; withCheckedContinuation is the safe Swift 6 alternative"),
        ("ActorReentrancyRule",          0.7, "Actor reentrancy risk: await on external call while holding actor state — potential data-consistency bug"),
        ("WithUnsafeCurrentTaskRule",    0.4, "Deprecated low-level task API; replace with structured concurrency (withTaskCancellationHandler, Task.checkCancellation)"),
        ("AsyncSequenceRule",            0.5, "Combine Subject ready for AsyncStream/AsyncThrowingStream migration — Swift 6 structured concurrency alternative"),
    ]

    /// Default weight for unknown rules.
    public static let defaultWeight: Double = 0.5

    // MARK: - Lookup

    /// Returns the complexity weight for a given rule name.
    /// Falls back to `defaultWeight` if the rule is not in the weight table.
    public static func weight(for rule: String) -> Double {
        weightTable.first { $0.rule == rule }?.weight ?? defaultWeight
    }

    // MARK: - Score Calculation
    // Score = SUM(finding × complexity weight)

    /// Computes the total migration score for all findings regardless of severity.
    /// - Note: Prefer `errorScore(for:)` in all production scoring paths — this method
    ///   is preserved for internal use and testing.
    public static func score(for findings: [Finding]) -> Double {
        findings.reduce(0.0) { accumulated, finding in
            accumulated + weight(for: finding.rule)
        }
    }

    /// Computes the migration score counting **only `.error`-severity findings**.
    ///
    /// `.warning` and `.info` findings are non-blocking recommendations; they do not
    /// contribute to the score and never cause a module to be labelled "Pending Migration".
    /// This is the sole production scoring path — `score(for:)` is not called directly
    /// from any reporter or analyzer.
    public static func errorScore(for findings: [Finding]) -> Double {
        score(for: findings.filter { $0.severity == .error })
    }

}
