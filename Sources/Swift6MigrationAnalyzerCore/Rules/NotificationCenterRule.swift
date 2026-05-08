import SwiftSyntax

/// Detects `NotificationCenter.default.addObserver` and `NotificationCenter.default.post`
/// calls without explicit actor isolation.
/// In Swift 6, notification observers that capture `self` from a `@MainActor` context
/// generate "Sending 'self' risks causing data races" warnings. The fix is to explicitly
/// annotate observer closures with `@MainActor` or use async notification sequences.
public struct NotificationCenterRule: Rule {
    public var name: String { "NotificationCenterRule" }
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

            if text.contains("NotificationCenter") && text.contains("addObserver") {
                let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .warning,
                    rule: "NotificationCenterRule",
                    message: "NotificationCenter.addObserver closure may capture actor-isolated state across concurrency boundaries; use NotificationCenter.notifications(named:) async sequence or annotate the closure with @MainActor"
                ))
            } else if text.contains("NotificationCenter") && text.contains(".post") {
                let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .warning,
                    rule: "NotificationCenterRule",
                    message: "NotificationCenter.post is not actor-safe; ensure it is called from the correct isolation context or replace with async/actor-based communication"
                ))
            }

            return .visitChildren
        }
    }
}
