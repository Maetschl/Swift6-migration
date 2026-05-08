import SwiftSyntax

/// Detects `@unchecked Sendable` conformances which bypass Swift 6 concurrency checks.
/// - SeeAlso: [UncheckedSendableRule documentation](../../../../Docs/Rules/UncheckedSendableRule.md)
public struct UncheckedSendableRule: Rule {
    public var name: String { "UncheckedSendableRule" }
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

        override func visit(_ node: InheritedTypeSyntax) -> SyntaxVisitorContinueKind {
            let typeText = node.type.description.trimmingCharacters(in: .whitespaces)
            if typeText == "@unchecked Sendable" {
                let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "UncheckedSendableRule",
                    message: "@unchecked Sendable bypasses Swift 6 concurrency checks; audit thread safety manually"
                ))
            }
            return .visitChildren
        }
    }
}
