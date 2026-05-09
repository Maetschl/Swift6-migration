import SwiftSyntax

/// Detects `DispatchGroup` usage.
///
/// `DispatchGroup` is a **Swift 6 compile error** under strict concurrency: callbacks passed
/// to `notify(queue:execute:)` and `enter()`/`leave()` pairs execute on untracked threads
/// that cannot be reasoned about by the actor isolation model. Sending `self` into these
/// callbacks produces "data races" compile errors.
///
/// In Swift 6, `async let` and `withTaskGroup` / `withThrowingTaskGroup` provide structured
/// concurrency equivalents with guaranteed actor isolation.
/// - SeeAlso: [DispatchGroupRule documentation](../../../../Docs/Rules/DispatchGroupRule.md)
public struct DispatchGroupRule: Rule {
    public var name: String { "DispatchGroupRule" }
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
        private var reportedLines = Set<Int>()

        init(file: String, converter: SourceLocationConverter) {
            self.file = file
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            for binding in node.bindings {
                if let typeAnnotation = binding.typeAnnotation {
                    let typeName = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)
                    if typeName == "DispatchGroup" {
                        report(node: Syntax(node))
                        return .visitChildren
                    }
                }
                if let initExpr = binding.initializer?.value {
                    let initText = initExpr.description.trimmingCharacters(in: .whitespaces)
                    if initText.hasPrefix("DispatchGroup(") || initText == "DispatchGroup" {
                        report(node: Syntax(node))
                        return .visitChildren
                    }
                }
            }
            return .visitChildren
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            let text = node.calledExpression.description.trimmingCharacters(in: .whitespaces)
            if text == "DispatchGroup" {
                report(node: Syntax(node))
            }
            return .visitChildren
        }

        private func report(node: Syntax) {
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            guard !reportedLines.contains(line) else { return }
            reportedLines.insert(line)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .error,
                rule: "DispatchGroupRule",
                message: "DispatchGroup callbacks execute on untracked threads, violating Swift 6 actor isolation boundaries — a compile error; replace with 'async let' or 'withTaskGroup' for structured concurrency"
            ))
        }
    }
}
