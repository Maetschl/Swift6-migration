import SwiftSyntax

/// Detects `Task.detached { }` which may cause actor isolation violations.
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
                    severity: .warning,
                    rule: "TaskDetachedRule",
                    message: "Task.detached may cause actor isolation violations; prefer Task { } or structured concurrency"
                ))
            }
            return .visitChildren
        }
    }
}
