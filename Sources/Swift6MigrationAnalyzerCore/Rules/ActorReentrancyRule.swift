import Foundation
import SwiftSyntax

/// Detects `async` actor methods that suspend on external calls.
///
/// Actors are reentrant: while an actor method is suspended at `await`, other tasks can
/// enter the same actor and mutate its state before the original task resumes. Swift 6
/// does not make this a compile error, but it is a common source of subtle logic bugs.
/// - SeeAlso: [ActorReentrancyRule documentation](../../../../Docs/Rules/ActorReentrancyRule.md)
public struct ActorReentrancyRule: Rule {
    public var name: String { "ActorReentrancyRule" }
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

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            for member in node.memberBlock.members {
                guard let function = member.decl.as(FunctionDeclSyntax.self),
                      function.signature.effectSpecifiers?.asyncSpecifier != nil,
                      let body = function.body,
                      ExternalAwaitVisitor.containsExternalAwait(in: body)
                else {
                    continue
                }

                let (line, col) = SourceLocationHelper.location(of: function, converter: converter)
                findings.append(Finding(
                    file: file,
                    line: line,
                    column: col,
                    severity: .warning,
                    rule: "ActorReentrancyRule",
                    message: "Actor method '\(function.name.text)' awaits an external call — actor reentrancy risk: state may change while suspended at 'await'; snapshot any state you rely on before the suspension point"
                ))
            }
            return .visitChildren
        }
    }

    private final class ExternalAwaitVisitor: SyntaxVisitor {
        private(set) var foundExternalAwait = false

        override init(viewMode: SyntaxTreeViewMode = .sourceAccurate) {
            super.init(viewMode: viewMode)
        }

        override func visit(_ node: AwaitExprSyntax) -> SyntaxVisitorContinueKind {
            if Self.isExternalAwait(node.expression) {
                foundExternalAwait = true
                return .skipChildren
            }
            return .visitChildren
        }

        static func containsExternalAwait(in body: CodeBlockSyntax) -> Bool {
            let visitor = ExternalAwaitVisitor()
            visitor.walk(body)
            return visitor.foundExternalAwait
        }

        private static func isExternalAwait(_ expression: ExprSyntax) -> Bool {
            if let tryExpr = expression.as(TryExprSyntax.self) {
                return isExternalAwait(tryExpr.expression)
            }

            if let forceUnwrap = expression.as(ForceUnwrapExprSyntax.self) {
                return isExternalAwait(forceUnwrap.expression)
            }

            if let optionalChain = expression.as(OptionalChainingExprSyntax.self) {
                return isExternalAwait(optionalChain.expression)
            }

            if let call = expression.as(FunctionCallExprSyntax.self) {
                return !isDirectSelfMemberAccess(call.calledExpression)
            }

            if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
                return !isDirectSelfMemberAccess(ExprSyntax(memberAccess))
            }

            return true
        }

        private static func isDirectSelfMemberAccess(_ expression: ExprSyntax) -> Bool {
            guard let memberAccess = expression.as(MemberAccessExprSyntax.self),
                  let base = memberAccess.base
            else {
                return false
            }

            return base.description.trimmingCharacters(in: .whitespacesAndNewlines) == "self"
        }
    }
}
