import SwiftSyntax

/// Detects `try!` expressions.
public struct ForceTryRule: Rule {
    public var name: String { "ForceTryRule" }
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

        override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
            if node.questionOrExclamationMark?.tokenKind == .exclamationMark {
                let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "ForceTryRule",
                    message: "try! will crash on error; use try/catch or try? instead"
                ))
            }
            return .visitChildren
        }
    }
}
