import SwiftSyntax

/// Detects DispatchQueue usage that violates Swift 6 strict concurrency.
///
/// All patterns produce **Swift 6 compilation errors** under strict concurrency mode:
/// - `.async` / `.asyncAfter` — the closure captures `self` across an actor isolation
///   boundary, causing "sending value of type X risks causing data races" compile errors.
/// - `.sync` — blocks the calling thread and bypasses actor isolation.
/// - `DispatchQueue(label:)` manual creation — unstructured thread management that the
///   compiler cannot reason about under Swift 6's isolation model.
///
/// Preferred Swift 6 replacements:
/// - `DispatchQueue.main.async { }` → `@MainActor` isolation or `await MainActor.run { }`
/// - `DispatchQueue.global().async { }` → `Task { }` or structured concurrency
/// - `.sync` → `await` on an actor method
/// - SeeAlso: [DispatchQueueRule documentation](../../../../Docs/Rules/DispatchQueueRule.md)
public struct DispatchQueueRule: Rule {
    public var name: String { "DispatchQueueRule" }
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

            guard text.hasPrefix("DispatchQueue") else { return .visitChildren }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)

            if text.contains(".sync") {
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "DispatchQueueRule",
                    message: "DispatchQueue.sync blocks the calling thread and bypasses actor isolation; replace with await on an actor method or async function"
                ))
            } else if text.contains(".async") {
                let isMain = text.contains(".main")
                let suggestion = isMain
                    ? "DispatchQueue.main.async captures 'self' across the MainActor boundary — a Swift 6 compile error; replace with '@MainActor' isolation or 'await MainActor.run { }'"
                    : "DispatchQueue.global().async sends a closure across an actor isolation boundary — a Swift 6 compile error; replace with 'Task { }' or structured concurrency"
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "DispatchQueueRule",
                    message: suggestion
                ))
            } else if text.hasSuffix("DispatchQueue") || text.contains("DispatchQueue(label:") || text.contains("DispatchQueue(") {
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "DispatchQueueRule",
                    message: "Manual DispatchQueue creation bypasses Swift 6 actor isolation; migrate to a Swift actor or structured concurrency to satisfy strict concurrency checking"
                ))
            }

            return .visitChildren
        }
    }
}
