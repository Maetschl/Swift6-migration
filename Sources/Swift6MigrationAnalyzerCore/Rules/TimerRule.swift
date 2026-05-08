import SwiftSyntax

/// Detects callback-based `Timer` API usage.
///
/// `Timer.scheduledTimer(withTimeInterval:repeats:block:)` fires on the RunLoop
/// thread and bypasses Swift 6 actor isolation.
///
/// Preferred Swift 6 alternatives:
/// - One-shot delay:  `Task { try await Task.sleep(for: .seconds(N)) }`
/// - Repeating timer: `AsyncStream`-based clock or a `withTaskGroup` loop
public struct TimerRule: Rule {
    public var name: String { "TimerRule" }
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
            guard text.hasPrefix("Timer") else { return .visitChildren }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "TimerRule",
                message: "Timer callback-based API fires on a RunLoop thread outside actor isolation; replace with 'Task { try await Task.sleep(for:) }' for one-shot delays or an AsyncStream-based repeating timer in Swift 6"
            ))
            return .visitChildren
        }
    }
}
