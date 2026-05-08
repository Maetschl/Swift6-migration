import Testing
import Foundation
import SwiftParser
import SwiftSyntax
@testable import Swift6MigrationAnalyzerCore

// MARK: - Helpers shared across all rule tests

func parse(_ source: String) -> SourceFileSyntax {
    Parser.parse(source: source)
}

func findings(
    from rule: some Rule,
    source: String,
    file: String = "Test.swift"
) -> [Finding] {
    let tree = parse(source)
    let converter = SourceLocationConverter(fileName: file, tree: tree)
    return rule.analyze(tree: tree, file: file, locationConverter: converter)
}
