import SwiftSyntax

/// Detects DispatchQueue usage that should be migrated to Swift 6 structured concurrency.
///
/// - `.main.async` / `.main.asyncAfter` / `global().async` → warning: prefer @MainActor or structured concurrency
/// - `.main.sync` / `.sync` → error: blocks the calling thread and bypasses actor isolation
public struct DispatchQueueRule: Rule {
    public var name: String { "DispatchQueueRule" }
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

            guard text.hasPrefix("DispatchQueue") else { return .visitChildren }

            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)

            if text.contains(".sync") {
                // .sync blocks the calling thread — error level in Swift 6 context
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "DispatchQueueRule",
                    message: "DispatchQueue.sync blocks the calling thread and bypasses actor isolation; replace with await on an actor method or async function"
                ))
            } else if text.contains(".async") {
                // .async is a warning — should move to @MainActor or Task { }
                let isMain = text.contains(".main")
                let suggestion = isMain
                    ? "Replace DispatchQueue.main.async with @MainActor isolated code or 'await MainActor.run { }'"
                    : "Replace DispatchQueue.global().async with a Swift concurrency Task or structured concurrency"
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .warning,
                    rule: "DispatchQueueRule",
                    message: suggestion
                ))
            } else if text.hasSuffix("DispatchQueue") || text.contains("DispatchQueue(label:") || text.contains("DispatchQueue(") {
                // Manual DispatchQueue creation
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .warning,
                    rule: "DispatchQueueRule",
                    message: "Manual DispatchQueue creation indicates custom thread management; consider migrating to a Swift actor for data isolation"
                ))
            }

            return .visitChildren
        }
    }
}
