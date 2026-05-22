import Foundation
import SwiftSyntax

/// Detects Combine subjects that are good candidates for `AsyncStream` migration.
///
/// `PassthroughSubject` and `CurrentValueSubject` are imperative event sources that can
/// often be replaced by `AsyncStream` / `AsyncThrowingStream` in Swift 6 codebases.
/// - SeeAlso: [AsyncSequenceRule documentation](../../../../Docs/Rules/AsyncSequenceRule.md)
public struct AsyncSequenceRule: Rule {
    public var name: String { "AsyncSequenceRule" }
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
        private var emittedKeys: Set<String> = []

        init(file: String, converter: SourceLocationConverter) {
            self.file = file
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
            emitIfNeeded(subjectName: node.name.text, node: Syntax(node))
            return .visitChildren
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            let callee = node.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if callee == "PassthroughSubject" || callee.hasPrefix("PassthroughSubject<") {
                emitIfNeeded(subjectName: "PassthroughSubject", node: Syntax(node))
            } else if callee == "CurrentValueSubject" || callee.hasPrefix("CurrentValueSubject<") {
                emitIfNeeded(subjectName: "CurrentValueSubject", node: Syntax(node))
            }
            return .visitChildren
        }

        private func emitIfNeeded(subjectName: String, node: Syntax) {
            guard let message = message(for: subjectName) else { return }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            let key = "\(subjectName):\(line)"
            guard emittedKeys.insert(key).inserted else { return }

            findings.append(Finding(
                file: file,
                line: line,
                column: col,
                severity: .warning,
                rule: "AsyncSequenceRule",
                message: message
            ))
        }

        private func message(for subjectName: String) -> String? {
            switch subjectName {
            case "PassthroughSubject":
                return "'PassthroughSubject' is a candidate for migration to 'AsyncStream' or 'AsyncThrowingStream' — Swift 6 structured concurrency alternative to Combine subjects"
            case "CurrentValueSubject":
                return "'CurrentValueSubject' is a candidate for migration to 'AsyncStream' with a current-value buffer — Swift 6 structured concurrency alternative to Combine subjects"
            default:
                return nil
            }
        }
    }
}
