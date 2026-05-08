import SwiftSyntax

/// Detects UIKit/AppKit view controller and view subclasses that lack an explicit
/// `@MainActor` annotation.
/// In Swift 6, the main actor inheritance from UIKit is enforced strictly. Explicit
/// `@MainActor` annotation makes the isolation visible and prevents "implicitly
/// asynchronous call to main-actor-isolated" warnings when calling these types from
/// non-isolated contexts.
/// - SeeAlso: [MainActorMissingRule documentation](../../../../Docs/Rules/MainActorMissingRule.md)
public struct MainActorMissingRule: Rule {
    public var name: String { "MainActorMissingRule" }
    public init() {}

    static let uiKitBaseClasses: Set<String> = [
        // UIKit view controllers
        "UIViewController", "UITableViewController", "UICollectionViewController",
        "UINavigationController", "UITabBarController", "UIPageViewController",
        "UISplitViewController",
        // UIKit views & cells
        "UIView", "UIControl", "UITableViewCell", "UICollectionViewCell",
        "UITableViewHeaderFooterView",
        // AppKit
        "NSViewController", "NSView", "NSWindowController", "NSWindow",
        // SwiftUI (UIHostingController is UIKit)
        "UIHostingController"
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

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            // Skip if already @MainActor
            let hasMainActor = node.attributes.description.contains("MainActor")
            guard !hasMainActor else { return .visitChildren }

            let inheritedNames = node.inheritanceClause?.inheritedTypes
                .map { $0.type.description.trimmingCharacters(in: .whitespaces) } ?? []

            guard let matched = inheritedNames.first(where: {
                MainActorMissingRule.uiKitBaseClasses.contains($0)
            }) else { return .visitChildren }

            let className = node.name.text
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "MainActorMissingRule",
                message: "'\(className)' inherits from '\(matched)' but lacks '@MainActor'; add @MainActor to make Swift 6 main-thread isolation explicit"
            ))
            return .visitChildren
        }
    }
}
