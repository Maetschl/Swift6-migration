import SwiftSyntax

/// Detects Combine framework usage that conflicts with Swift 6 actor isolation.
///
/// Patterns are split by severity:
///
/// **`.error` — Swift 6 compile errors:**
/// - `.sink { }` — the closure executes on an arbitrary scheduler thread; capturing
///   actor-isolated `self` produces "sending value of type X risks causing data races".
/// - `assign(to:on:)` — sends values to `self` across an actor isolation boundary,
///   producing the same data-race compile error.
///
/// **`.warning` — non-blocking recommendation:**
/// - `AnyCancellable` storage — the storage itself is fine; it signals active Combine
///   subscriptions that should eventually migrate to async sequences.
///
/// Preferred Swift 6 alternatives: `.values` async sequence with `for await`,
/// `AsyncStream`, or `assign(to:)` with `@Observable`.
/// - SeeAlso: [CombineRule documentation](../../../../Docs/Rules/CombineRule.md)
public struct CombineRule: Rule {
    public var name: String { "CombineRule" }
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
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)

            if text.hasSuffix(".sink") {
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "CombineRule",
                    message: "Combine .sink closure executes on an arbitrary scheduler thread, sending self across an actor isolation boundary — a Swift 6 compile error; migrate to '.values' async sequence with 'for await' or an AsyncStream"
                ))
            } else if text.hasSuffix(".assign") || text.contains("assign(to:on:)") {
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "CombineRule",
                    message: "Combine assign(to:on:) sends values to 'self' across an actor isolation boundary — a Swift 6 compile error; use 'assign(to:)' on an '@Observable' type or migrate to an async sequence"
                ))
            }

            return .visitChildren
        }

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            for binding in node.bindings {
                if let typeAnnotation = binding.typeAnnotation {
                    let typeName = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)
                    if typeName.contains("AnyCancellable") {
                        let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
                        findings.append(Finding(
                            file: file, line: line, column: col,
                            severity: .warning,
                            rule: "CombineRule",
                            message: "AnyCancellable storage indicates active Combine subscriptions; consider migrating to Swift Concurrency async sequences for Swift 6 actor-safe observation"
                        ))
                        break
                    }
                }
            }
            return .visitChildren
        }
    }
}
