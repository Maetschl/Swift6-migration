import SwiftSyntax

/// Detects `await MainActor.run { }` calls inside non-isolated, non-Sendable classes.
///
/// In Swift 6 strict concurrency, calling `await MainActor.run { }` from a non-isolated
/// async context while capturing `self` (a non-Sendable, non-actor class) is a **compile error**:
/// > "Sending 'self' risks causing data races"
///
/// Preferred Swift 6 fixes:
/// - Annotate the class with `@MainActor`.
/// - Conform to `Sendable`.
/// - Pass only Sendable value types into the closure instead of `self`.
/// - SeeAlso: [MainActorRunRule documentation](../../../../Docs/Rules/MainActorRunRule.md)
public struct MainActorRunRule: Rule {
    public var name: String { "MainActorRunRule" }
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
        private var classStack: [(name: String, isMainActor: Bool, isActor: Bool)] = []

        init(file: String, converter: SourceLocationConverter) {
            self.file = file
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            let attrs = node.attributes.description
            classStack.append((name: node.name.text, isMainActor: attrs.contains("MainActor"), isActor: false))
            return .visitChildren
        }
        override func visitPost(_ node: ClassDeclSyntax) { classStack.removeLast() }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            classStack.append((name: node.name.text, isMainActor: false, isActor: true))
            return .visitChildren
        }
        override func visitPost(_ node: ActorDeclSyntax) { classStack.removeLast() }

        override func visit(_ node: AwaitExprSyntax) -> SyntaxVisitorContinueKind {
            guard let enclosing = classStack.last,
                  !enclosing.isActor,
                  !enclosing.isMainActor else { return .visitChildren }

            guard let call = node.expression.as(FunctionCallExprSyntax.self) else { return .visitChildren }
            let callee = call.calledExpression.description.trimmingCharacters(in: .whitespaces)
            guard callee == "MainActor.run" else { return .visitChildren }
            guard call.description.contains("self") else { return .visitChildren }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .error,
                rule: "MainActorRunRule",
                message: "Sending 'self' (a non-Sendable '\(enclosing.name)') into 'await MainActor.run' from a non-isolated async context risks causing data races — a Swift 6 compile error; mark '\(enclosing.name)' as '@MainActor', conform it to 'Sendable', or pass only Sendable values into the closure"
            ))
            return .visitChildren
        }
    }
}
