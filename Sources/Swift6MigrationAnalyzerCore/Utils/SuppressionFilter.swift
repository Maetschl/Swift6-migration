/// Filters findings based on inline suppression comments in the source.
///
/// Suppression comments must appear on the **same line** as the flagged code
/// or on the line **immediately before** it.
///
/// ## Supported syntax
///
/// ### Suppress all rules on a line
/// ```swift
/// let x = DispatchQueue.main.async { } // swift6-analyzer: ignore
/// ```
///
/// ### Suppress a specific rule on a line
/// ```swift
/// let x = DispatchQueue.main.async { } // swift6-analyzer: ignore DispatchQueueRule
/// ```
///
/// ### Suppress from the line above (trailing comment not always practical)
/// ```swift
/// // swift6-analyzer: ignore GlobalMutableStateRule
/// var sharedState = 0
/// ```
///
/// Suppression comments are case-sensitive and must start with the exact prefix
/// `swift6-analyzer: ignore` (with a colon and a space).
public struct SuppressionFilter: Sendable {

    /// Marker prefix that all suppression comments must begin with.
    static let prefix = "swift6-analyzer: ignore"

    /// Filters out findings that are suppressed by an inline comment in the source.
    ///
    /// - Parameters:
    ///   - findings: The full list of findings for a single source file.
    ///   - source: The raw source text of that file.
    /// - Returns: The subset of findings that are **not** suppressed.
    public static func filter(findings: [Finding], source: String) -> [Finding] {
        guard !findings.isEmpty else { return findings }

        // Build a line-number → source-line lookup (1-indexed to match findings)
        let lines = source.components(separatedBy: "\n")

        return findings.filter { finding in
            !isSuppressed(finding: finding, lines: lines)
        }
    }

    // MARK: - Private helpers

    private static func isSuppressed(finding: Finding, lines: [String]) -> Bool {
        let line = finding.line   // 1-indexed
        let rule = finding.rule

        // Check the same line as the finding (handles both trailing and standalone comments)
        if let sameLine = sourceLine(at: line, in: lines) {
            if isIgnored(line: sameLine, rule: rule) { return true }
        }

        // Check the line immediately before ONLY if it is a standalone comment line.
        // A trailing comment on code (e.g. `var x = 0 // ignore`) should only suppress
        // findings on that same line, not the next one.
        if let prevLine = sourceLine(at: line - 1, in: lines) {
            if isStandaloneComment(prevLine) && isIgnored(line: prevLine, rule: rule) { return true }
        }

        return false
    }

    /// Returns true if the trimmed line consists only of a `//` comment (no preceding code).
    private static func isStandaloneComment(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
    }

    /// Returns the source line at the given 1-indexed line number, or nil if out of bounds.
    private static func sourceLine(at lineNumber: Int, in lines: [String]) -> String? {
        let index = lineNumber - 1   // convert to 0-indexed
        guard index >= 0, index < lines.count else { return nil }
        return lines[index]
    }

    /// Returns true if the given source line contains a suppression comment for `rule`.
    ///
    /// Matches:
    /// - `// swift6-analyzer: ignore`           → suppresses any rule
    /// - `// swift6-analyzer: ignore RuleName`  → suppresses only `RuleName`
    private static func isIgnored(line: String, rule: String) -> Bool {
        guard let range = line.range(of: prefix) else { return false }
        let afterPrefix = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        // No rule name specified → suppress all rules on this line
        if afterPrefix.isEmpty { return true }
        // Rule name specified → suppress only if it matches
        return afterPrefix == rule
    }
}
