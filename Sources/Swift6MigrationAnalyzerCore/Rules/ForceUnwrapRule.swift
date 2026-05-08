import SwiftSyntax

/// Detects force-unwrap (`value!`) and force-try (`try!`) expressions.
public struct ForceUnwrapRule: Rule {
    public var name: String { "ForceUnwrapRule" }
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

        override func visit(_ node: ForceUnwrapExprSyntax) -> SyntaxVisitorContinueKind {
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "ForceUnwrapRule",
                message: "Force unwrap (!) can crash at runtime; use optional binding or guard instead"
            ))
            return .visitChildren
        }
    }
}
