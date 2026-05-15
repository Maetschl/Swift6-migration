import SwiftSyntax

/// Detects `withUnsafeContinuation` and `withUnsafeThrowingContinuation` usages.
///
/// In Swift 6, the preferred API is `withCheckedContinuation` /
/// `withCheckedThrowingContinuation`. The "checked" variants enforce that the
/// continuation is resumed **exactly once** — violating this is a runtime trap,
/// making bugs much easier to catch during development. The "unsafe" variants
/// skip this check and will silently corrupt task state if resumed zero or
/// multiple times.
///
/// Swift 6 strict concurrency does not make the unsafe variants a compile error,
/// but their use is a strong code-quality signal that the safer alternative
/// should be used instead.
///
/// SeeAlso: [CheckedContinuationRule documentation](../../../../Docs/Rules/CheckedContinuationRule.md)
public struct CheckedContinuationRule: Rule {
    public var name: String { "CheckedContinuationRule" }
    public init() {}

    public func analyze(
        tree: SourceFileSyntax,
        file: String,
        locationConverter: SourceLocationConverter
    ) -> [Finding] {
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
            let callee = node.calledExpression.description
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: "(").first ?? ""

            switch callee {
            case "withUnsafeContinuation":
                emit(node: node, unsafe: "withUnsafeContinuation", safe: "withCheckedContinuation")
            case "withUnsafeThrowingContinuation":
                emit(node: node, unsafe: "withUnsafeThrowingContinuation", safe: "withCheckedThrowingContinuation")
            default:
                break
            }
            return .visitChildren
        }

        private func emit(node: FunctionCallExprSyntax, unsafe: String, safe: String) {
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "CheckedContinuationRule",
                message: "\(unsafe) skips resume-count validation — replace with \(safe) to catch resume errors (called zero or multiple times) at runtime during development"
            ))
        }
    }
}
