import SwiftSyntax

/// Detects usage of manual synchronization primitives (NSLock, NSRecursiveLock,
/// DispatchSemaphore, NSCondition, pthread_mutex_t, os_unfair_lock).
/// These indicate hand-rolled thread safety that should be migrated to actors in Swift 6.
public struct SynchronizationPrimitiveRule: Rule {
    public var name: String { "SynchronizationPrimitiveRule" }
    public init() {}

    static let primitives: Set<String> = [
        "NSLock", "NSRecursiveLock", "NSCondition", "NSConditionLock",
        "DispatchSemaphore", "pthread_mutex_t", "os_unfair_lock",
        "os_unfair_lock_t", "OSAllocatedUnfairLock"
    ]

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
            for binding in node.bindings {
                // Check explicit type annotation: var lock: NSLock
                if let typeAnnotation = binding.typeAnnotation {
                    let typeName = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)
                    if SynchronizationPrimitiveRule.primitives.contains(typeName) {
                        report(node: Syntax(node), primitiveName: typeName)
                        continue
                    }
                }
                // Check initializer expression: var lock = NSLock()
                if let initExpr = binding.initializer?.value {
                    let initText = initExpr.description.trimmingCharacters(in: .whitespaces)
                    if let matched = SynchronizationPrimitiveRule.primitives.first(where: {
                        initText.hasPrefix($0 + "(") || initText == $0
                    }) {
                        report(node: Syntax(node), primitiveName: matched)
                    }
                }
            }
            return .visitChildren
        }

        private func report(node: Syntax, primitiveName: String) {
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "SynchronizationPrimitiveRule",
                message: "'\(primitiveName)' is a manual synchronization primitive; consider migrating to an actor for Swift 6 data isolation"
            ))
        }
    }
}
