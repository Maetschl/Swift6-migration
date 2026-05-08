import SwiftSyntax

public protocol Rule: Sendable {
    var name: String { get }
    func analyze(tree: SourceFileSyntax, file: String, locationConverter: SourceLocationConverter) -> [Finding]
}
