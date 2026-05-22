import Foundation

/// Configuration loaded from `.swift6-analyzer.json` at the project root (or `--config <path>`).
///
/// All fields are optional. CLI flags take precedence over values in the config file.
///
/// Example `.swift6-analyzer.json`:
/// ```json
/// {
///   "exclude": ["Mocks", "Generated"],
///   "maxDepth": 3,
///   "includeTests": false,
///   "disabledRules": ["ObservableObjectRule"],
///   "severityOverrides": {
///     "CompletionHandlerRule": "info"
///   },
///   "report": ["html", "json"],
///   "baseline": "baseline.json",
///   "saveBaseline": "baseline.json"
/// }
/// ```
public struct AnalyzerConfig: Codable, Sendable {
    /// Additional directory names to exclude from scanning.
    public var exclude: [String]?
    /// Maximum module nesting depth (mirrors `--max-depth`).
    public var maxDepth: Int?
    /// Include `Tests` and `SnapshotTests` directories (mirrors `--include-tests`).
    public var includeTests: Bool?
    /// Rule names to disable entirely.
    public var disabledRules: [String]?
    /// Override severity for specific rules. Valid values: `"error"`, `"warning"`, `"info"`.
    public var severityOverrides: [String: String]?
    /// Default report format(s) (mirrors `--report`).
    public var report: [String]?
    /// Path to baseline JSON file for diff mode (mirrors `--baseline`).
    public var baseline: String?
    /// Path to save the current run as a baseline (mirrors `--save-baseline`).
    public var saveBaseline: String?

    public init() {}
}
