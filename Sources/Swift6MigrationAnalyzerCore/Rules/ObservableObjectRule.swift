import SwiftSyntax

/// Detects `ObservableObject` protocol conformances.
/// In Swift 5.9+ / Swift 6, the `@Observable` macro replaces `ObservableObject` + `@Published`.
/// Migrating removes the need for `@Published`, reduces boilerplate, and avoids
/// main-thread observation issues that cause Swift 6 concurrency warnings.
/// - SeeAlso: [ObservableObjectRule documentation](../../../../Docs/Rules/ObservableObjectRule.md)
public struct ObservableObjectRule: Rule {
    public var name: String { "ObservableObjectRule" }
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

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            checkInheritance(of: node.inheritanceClause, declNode: Syntax(node))
            return .visitChildren
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            checkInheritance(of: node.inheritanceClause, declNode: Syntax(node))
            return .visitChildren
        }

        private func checkInheritance(of clause: InheritanceClauseSyntax?, declNode: Syntax) {
            guard let clause else { return }
            for inherited in clause.inheritedTypes {
                let typeName = inherited.type.description.trimmingCharacters(in: .whitespaces)
                if typeName == "ObservableObject" {
                    let (line, col) = SourceLocationHelper.location(of: declNode, converter: converter)
                    findings.append(Finding(
                        file: file, line: line, column: col,
                        severity: .warning,
                        rule: "ObservableObjectRule",
                        message: "Migrate from ObservableObject + @Published to the @Observable macro (Swift 5.9+); this eliminates main-thread observation issues in Swift 6"
                    ))
                }
            }
        }
    }
}
