import SwiftSyntax

/// Detects direct use of the `Thread` class for concurrency control.
///
/// `Thread` is a low-level Objective-C-era API that operates below Swift 6's actor isolation
/// model. Patterns are split by severity:
///
/// **`.error` — Swift 6 compile errors:**
/// - `Thread.detachNewThread { }` / `Thread(block:)` — creates an untracked thread outside
///   actor isolation; sending `self` into the closure is a "data races" compile error.
///
/// **`.warning` — runtime checks that don't compose with actor isolation:**
/// - `Thread.isMainThread` / `Thread.main` / `Thread.current` — thread-level checks that
///   give false results inside `@MainActor`-isolated code called from a background thread.
///   Not a compile error, but a correctness hazard.
///
/// - SeeAlso: [ThreadRule documentation](../../../../Docs/Rules/ThreadRule.md)
public struct ThreadRule: Rule {
    public var name: String { "ThreadRule" }
    public init() {}

    public func analyze(tree: SourceFileSyntax, file: String, locationConverter: SourceLocationConverter) -> [Finding] {
        let visitor = Visitor(file: file, converter: locationConverter)
        visitor.walk(tree)
        return visitor.findings
    }

    private final class Visitor: SyntaxVisitor {
        var findings: [Finding] = []
        let file: String
        let converter: SourceLocationConverter

        init(file: String, converter: SourceLocationConverter) {
            self.file = file
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            let text = node.calledExpression.description.trimmingCharacters(in: .whitespaces)
            guard text.hasPrefix("Thread") else { return .visitChildren }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .error,
                rule: "ThreadRule",
                message: "Direct Thread API usage creates an untracked thread outside actor isolation — a Swift 6 compile error; replace with a Swift actor, '@MainActor', or structured concurrency Tasks"
            ))
            return .visitChildren
        }

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            let text = node.description.trimmingCharacters(in: .whitespaces)
            guard text == "Thread.main" || text == "Thread.isMainThread" || text == "Thread.current" else {
                return .visitChildren
            }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "ThreadRule",
                message: "'\(text)' is a thread-level check that does not compose with Swift 6 actor isolation; use '@MainActor' isolation context or 'MainActor.assertIsolated()' instead"
            ))
            return .visitChildren
        }
    }
}
