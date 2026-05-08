import SwiftSyntax

/// Detects top-level (file-scope) `var` declarations that are not actor-isolated.
/// In Swift 6, non-isolated global mutable state is a compile error:
/// "Var 'X' is not concurrency-safe because it is non-isolated global shared mutable state."
public struct GlobalMutableStateRule: Rule {
    public var name: String { "GlobalMutableStateRule" }
    public init() {}

    public func analyze(tree: SourceFileSyntax, file: String, locationConverter: SourceLocationConverter) -> [Finding] {
        var findings: [Finding] = []

        for statement in tree.statements {
            guard let varDecl = statement.item.as(VariableDeclSyntax.self) else { continue }
            // Only flag stored `var`, not `let`
            guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else { continue }

            // Skip if already annotated with @MainActor or nonisolated
            let attributeText = varDecl.attributes.description
            if attributeText.contains("MainActor") || attributeText.contains("nonisolated") { continue }

            for binding in varDecl.bindings {
                // Skip computed properties (they have an accessor block)
                if binding.accessorBlock != nil { continue }

                let varName = binding.pattern.description.trimmingCharacters(in: .whitespaces)
                let (line, col) = SourceLocationHelper.location(of: varDecl, converter: locationConverter)
                findings.append(Finding(
                    file: file, line: line, column: col,
                    severity: .error,
                    rule: "GlobalMutableStateRule",
                    message: "Global variable '\(varName)' is not concurrency-safe; in Swift 6 this is an error — isolate it with @MainActor, wrap in an actor, or make it a `let` constant"
                ))
            }
        }

        return findings
    }
}
