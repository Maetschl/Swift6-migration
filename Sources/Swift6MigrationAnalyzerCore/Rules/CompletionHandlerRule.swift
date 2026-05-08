import SwiftSyntax

/// Detects completion handler patterns (`completion: @escaping (...)`) as candidates for async/await.
public struct CompletionHandlerRule: Rule {
    public var name: String { "CompletionHandlerRule" }
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

        override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
            let paramName = node.firstName.text
            let typeText = node.type.description

            let isEscaping = typeText.contains("@escaping")
            let isCompletionName = paramName.lowercased().contains("completion")
                || paramName.lowercased().contains("handler")
                || paramName.lowercased().contains("callback")

            if isEscaping && isCompletionName {
                let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .warning,
                    rule: "CompletionHandlerRule",
                    message: "Completion handler '\(paramName)' is a candidate for async/await migration"
                ))
            }
            return .visitChildren
        }
    }
}
