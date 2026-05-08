import SwiftSyntax

/// Detects `OperationQueue.main.addOperation` usage.
/// `OperationQueue.main` is the Objective-C era equivalent of `DispatchQueue.main`.
/// In Swift 6, prefer `@MainActor` isolation or `Task { @MainActor in ... }`.
/// - SeeAlso: [OperationQueueMainRule documentation](../../../../Docs/Rules/OperationQueueMainRule.md)
public struct OperationQueueMainRule: Rule {
    public var name: String { "OperationQueueMainRule" }
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
            if text.contains("OperationQueue.main") {
                let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .warning,
                    rule: "OperationQueueMainRule",
                    message: "Replace OperationQueue.main with @MainActor isolation or 'Task { @MainActor in ... }' for Swift 6 concurrency"
                ))
            }
            return .visitChildren
        }
    }
}
