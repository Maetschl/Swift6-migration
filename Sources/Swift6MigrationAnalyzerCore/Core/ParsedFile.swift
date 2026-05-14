import Foundation
import SwiftSyntax
import SwiftParser

/// A Swift source file parsed exactly once — holds the source text, syntax tree,
/// and line count so downstream passes (rules, indicator collector, line counter)
/// share a single disk read and a single SwiftSyntax parse.
public struct ParsedFile: Sendable {
    public let url: URL
    public let source: String
    public let tree: SourceFileSyntax
    public let lineCount: Int

    public init(url: URL, source: String) {
        self.url       = url
        self.source    = source
        self.tree      = Parser.parse(source: source)
        self.lineCount = source
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }
}
