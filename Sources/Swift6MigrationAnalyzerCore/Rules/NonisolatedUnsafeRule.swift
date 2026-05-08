import SwiftSyntax

/// Detects `nonisolated(unsafe)` stored property declarations.
///
/// `nonisolated(unsafe)` is a Swift 6 escape hatch that disables concurrency
/// checking for a specific stored property. It is the property-level equivalent
/// of `@unchecked Sendable`: the compiler trusts you that access is safe, but
/// data races are possible if the property is accessed from multiple isolation
/// domains simultaneously.
///
/// Every occurrence must be manually audited and replaced with proper actor
/// isolation, a `Mutex`/`OSAllocatedUnfairLock`, or a `Sendable` value type.
/// - SeeAlso: [NonisolatedUnsafeRule documentation](../../../../Docs/Rules/NonisolatedUnsafeRule.md)
public struct NonisolatedUnsafeRule: Rule {
    public var name: String { "NonisolatedUnsafeRule" }
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

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            let hasNonisolatedUnsafe = node.modifiers.contains { modifier in
                modifier.description.trimmingCharacters(in: .whitespaces).contains("nonisolated(unsafe)")
            }
            guard hasNonisolatedUnsafe else { return .visitChildren }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .error,
                rule: "NonisolatedUnsafeRule",
                message: "'nonisolated(unsafe)' suppresses Swift 6 concurrency checking for this property; audit all access sites for data races and replace with actor isolation, 'Mutex', or a 'Sendable' value type"
            ))
            return .visitChildren
        }
    }
}
