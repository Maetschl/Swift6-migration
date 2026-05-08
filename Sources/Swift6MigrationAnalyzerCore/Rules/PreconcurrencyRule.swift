import SwiftSyntax

/// Detects `@preconcurrency` on import declarations and protocol conformances.
///
/// `@preconcurrency` is a Swift 6 migration bridge that suppresses concurrency
/// warnings/errors coming from pre-Swift 6 modules or protocol conformances.
/// It is intended as a **temporary** escape hatch, not a permanent solution.
///
/// Every `@preconcurrency` annotation represents a suppressed Swift 6 issue
/// that must eventually be resolved by adding proper `Sendable` conformances
/// or actor isolation to the offending types.
/// - SeeAlso: [PreconcurrencyRule documentation](../../../../Docs/Rules/PreconcurrencyRule.md)
public struct PreconcurrencyRule: Rule {
    public var name: String { "PreconcurrencyRule" }
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

        override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
            guard node.attributes.description.contains("preconcurrency") else { return .visitChildren }
            let moduleName = node.path.description.trimmingCharacters(in: .whitespaces)
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "PreconcurrencyRule",
                message: "@preconcurrency import suppresses Swift 6 concurrency warnings from '\(moduleName)'; treat as a temporary bridge and audit conformances to remove this suppression"
            ))
            return .visitChildren
        }

        override func visit(_ node: InheritedTypeSyntax) -> SyntaxVisitorContinueKind {
            let text = node.description.trimmingCharacters(in: .whitespaces)
            guard text.hasPrefix("@preconcurrency") else { return .visitChildren }
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "PreconcurrencyRule",
                message: "@preconcurrency on a protocol conformance suppresses Swift 6 Sendable and isolation checks; audit the conformance and remove this annotation once proper isolation is in place"
            ))
            return .visitChildren
        }
    }
}
