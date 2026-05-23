import Foundation
import SwiftSyntax

/// Detects deprecated low-level task inspection APIs.
///
/// `withUnsafeCurrentTask` and `Task.current` were deprecated in Swift 5.9+ because they
/// expose task internals and encourage imperative patterns that work against structured
/// concurrency.
/// - SeeAlso: [WithUnsafeCurrentTaskRule documentation](../../../../Docs/Rules/WithUnsafeCurrentTaskRule.md)
public struct WithUnsafeCurrentTaskRule: Rule {
    public var name: String { "WithUnsafeCurrentTaskRule" }
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
            let callee = node.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard callee == "withUnsafeCurrentTask" else {
                return .visitChildren
            }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file,
                line: line,
                column: col,
                severity: .warning,
                rule: "WithUnsafeCurrentTaskRule",
                message: "'withUnsafeCurrentTask' is deprecated in Swift 5.9+; use 'withTaskCancellationHandler' or 'TaskGroup' for cancellation propagation"
            ))
            return .visitChildren
        }

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            guard let base = node.base,
                  base.description.trimmingCharacters(in: .whitespacesAndNewlines) == "Task",
                  node.declName.baseName.text == "current"
            else {
                return .visitChildren
            }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file,
                line: line,
                column: col,
                severity: .warning,
                rule: "WithUnsafeCurrentTaskRule",
                message: "'Task.current' is deprecated; use structured concurrency ('async let', 'withTaskGroup') to avoid needing direct task references"
            ))
            return .visitChildren
        }
    }
}
