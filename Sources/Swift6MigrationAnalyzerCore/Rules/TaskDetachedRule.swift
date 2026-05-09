import SwiftSyntax

/// Detects `Task.detached { }` which causes actor isolation violations in Swift 6.
///
/// `Task.detached` is a **Swift 6 compile error** in many contexts: it drops the caller's
/// actor context entirely and creates a task with no isolation. Any capture of actor-isolated
/// state (`self`, `@MainActor` properties) across the detached boundary produces
/// "sending value of type X risks causing data races" compile errors.
///
/// Preferred Swift 6 alternatives:
/// - `Task { }` — inherits the caller's actor context (no isolation drop)
/// - `withTaskGroup` / `async let` — structured concurrency with safe value passing
/// - SeeAlso: [TaskDetachedRule documentation](../../../../Docs/Rules/TaskDetachedRule.md)
public struct TaskDetachedRule: Rule {
    public var name: String { "TaskDetachedRule" }
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
            if text == "Task.detached" {
                let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "TaskDetachedRule",
                    message: "Task.detached drops the caller's actor context and may send non-Sendable values across isolation boundaries — a Swift 6 compile error; use Task { } to inherit isolation or restructure with structured concurrency"
                ))
            }
            return .visitChildren
        }
    }
}
