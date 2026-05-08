import Foundation
import SwiftParser
import SwiftSyntax

public struct Analyzer: Sendable {
    private let rules: [any Rule]

    public init(rules: [any Rule] = Self.defaultRules) {
        self.rules = rules
    }

    // MARK: - Rule sets

    /// Swift 6 concurrency migration rules (default set).
    public static var defaultRules: [any Rule] {
        [
            GlobalMutableStateRule(),
            NonisolatedUnsafeRule(),
            DispatchQueueRule(),
            DispatchGroupRule(),
            TaskDetachedRule(),
            CompletionHandlerRule(),
            UncheckedSendableRule(),
            PreconcurrencyRule(),
            ObservableObjectRule(),
            SynchronizationPrimitiveRule(),
            MainActorMissingRule(),
            NotificationCenterRule(),
            OperationQueueMainRule(),
            TimerRule(),
            CombineRule(),
            ThreadRule(),
        ]
    }

    /// Optional code-quality rules (not Swift 6 specific).
    public static var qualityRules: [any Rule] {
        [
            ForceUnwrapRule(),
            ForceTryRule(),
        ]
    }

    /// All rules combined (default + quality).
    public static var allRules: [any Rule] {
        defaultRules + qualityRules
    }

    // MARK: - Module-aware analysis (primary entry point)

    /// Detects modules inside `directory` recursively up to `maxDepth`, analyzes each one,
    /// and returns `ModuleResult` per module in depth-first tree order.
    public func analyzeModules(
        in directory: URL,
        fileScanner: FileScanner,
        maxDepth: Int = 4
    ) -> [ModuleResult] {
        let moduleScanner = ModuleScanner(fileScanner: fileScanner, maxDepth: maxDepth)
        let modules = moduleScanner.detectModules(in: directory)

        return modules.map { module in
            let findings = analyze(files: module.sourceFiles)
            let linesOfCode = countLines(in: module.sourceFiles)
            let indicators = collectIndicators(in: module.sourceFiles)
            let score = FindingComplexity.score(for: findings)
            let status: MigrationStatus = score == 0 ? .migrated : .pendingMigration

            return ModuleResult(
                name: module.name,
                qualifiedName: module.qualifiedName,
                path: module.rootURL.path,
                status: status,
                score: score,
                fileCount: module.sourceFiles.count,
                totalLinesOfCode: linesOfCode,
                findings: findings,
                migrationIndicators: indicators,
                depth: module.depth,
                parentQualifiedName: module.parentQualifiedName
            )
        }
        // Keep depth-first tree order from scanner; stable sort within siblings by name
        // (scanner already returns them sorted alphabetically within each depth level)
    }

    /// Wraps a single file in a one-module result.
    public func analyzeAsModule(file: URL) -> ModuleResult {
        let findings = analyze(file: file)
        let linesOfCode = countLines(in: [file])
        let indicators = collectIndicators(in: [file])
        let score = FindingComplexity.score(for: findings)
        let name = file.deletingPathExtension().lastPathComponent
        return ModuleResult(
            name: name,
            qualifiedName: name,
            path: file.path,
            status: score == 0 ? .migrated : .pendingMigration,
            score: score,
            fileCount: 1,
            totalLinesOfCode: linesOfCode,
            findings: findings,
            migrationIndicators: indicators,
            depth: 0,
            parentQualifiedName: nil
        )
    }

    // MARK: - Flat analysis

    public func analyze(files: [URL]) -> [Finding] {
        var findings: [Finding] = []
        for fileURL in files {
            findings.append(contentsOf: analyze(file: fileURL))
        }
        return findings.sorted { ($0.file, $0.line) < ($1.file, $1.line) }
    }

    private func analyze(file: URL) -> [Finding] {
        guard let source = try? String(contentsOf: file, encoding: .utf8) else {
            print("⚠️  Could not read \(file.path)")
            return []
        }
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file.path, tree: tree)
        var findings: [Finding] = []
        for rule in rules {
            findings.append(contentsOf: rule.analyze(tree: tree, file: file.path, locationConverter: converter))
        }
        return findings
    }

    // MARK: - Migration indicator collection

    private func collectIndicators(in files: [URL]) -> MigrationIndicators {
        var total = MigrationIndicatorCollector()
        for fileURL in files {
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let tree = Parser.parse(source: source)
            let collector = MigrationIndicatorCollector()
            collector.walk(tree)
            total = MigrationIndicatorCollector.merge(total, collector)
        }
        return total.build()
    }

    // MARK: - Line counter

    private func countLines(in files: [URL]) -> Int {
        files.reduce(0) { count, url in
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return count }
            let nonEmptyLines = content
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count
            return count + nonEmptyLines
        }
    }
}
