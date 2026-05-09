import SwiftSyntax

/// A Swift 6 migration rule that analyses a single source file's syntax tree
/// and returns zero or more ``Finding`` instances describing migration issues.
///
/// ## Severity contract
///
/// Conforming types **must** choose severity carefully:
/// - Use `.error` for patterns that **cause Swift 6 compilation errors** (e.g. non-isolated
///   global mutable state, `nonisolated(unsafe)`, `@unchecked Sendable`).
///   Error findings contribute to the module's migration score and trigger "Pending Migration".
/// - Use `.warning` for patterns that are **non-blocking recommendations** (e.g. migrating
///   `ObservableObject` to `@Observable`, replacing `Timer` with `Task.sleep`).
///   Warning findings appear in reports but score 0 and never block migration status.
/// - Use `.info` for purely informational observations.
///
/// ## Implementation notes
///
/// - Rules must be `Sendable` (value-type structs are preferred).
/// - Rules must be stateless; they receive a fresh `SourceFileSyntax` tree per file.
/// - Use `SourceLocationHelper.location(of:converter:)` to produce accurate line/column info.
public protocol Rule: Sendable {
    /// The unique identifier for this rule, used in ``Finding/rule`` and the complexity table.
    var name: String { get }
    /// Analyses `tree` and returns all findings for the given `file`.
    func analyze(tree: SourceFileSyntax, file: String, locationConverter: SourceLocationConverter) -> [Finding]
}
