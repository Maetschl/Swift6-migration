import SwiftSyntax

public struct SourceLocationHelper {
    public static func location(
        of node: some SyntaxProtocol,
        converter: SourceLocationConverter
    ) -> (line: Int, column: Int) {
        let loc = node.startLocation(converter: converter)
        return (line: loc.line, column: loc.column)
    }
}
