import Foundation
import SwiftParser
import SwiftSyntax

public struct Analyzer: Sendable {
    private let rules: [any Rule]

    public init(rules: [any Rule] = Self.defaultRules) {
        self.rules = rules
    }

    // MARK: - Rule sets

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

    public static var qualityRules: [any Rule] {
        [ForceUnwrapRule(), ForceTryRule()]
    }

    public static var allRules: [any Rule] { defaultRules + qualityRules }

    // MARK: - Module-aware analysis

    /// Detects modules recursively up to `maxDepth`, analyzes each, and returns
    /// results in depth-first tree order with aggregate scores and child lists computed.
    public func analyzeModules(
        in directory: URL,
        fileScanner: FileScanner,
        maxDepth: Int = 4
    ) -> [ModuleResult] {
        let moduleScanner = ModuleScanner(fileScanner: fileScanner, maxDepth: maxDepth)
        let modules = moduleScanner.detectModules(in: directory)

        // Step 1 — build raw results (own score/findings only, no aggregate yet)
        var rawResults: [ModuleResult] = modules.map { module in
            let findings    = analyze(files: module.sourceFiles)
            let linesOfCode = countLines(in: module.sourceFiles)
            let indicators  = collectIndicators(in: module.sourceFiles)
            let score       = FindingComplexity.score(for: findings)
            return ModuleResult(
                name: module.name,
                qualifiedName: module.qualifiedName,
                path: module.rootURL.path,
                status: score == 0 ? .migrated : .pendingMigration,
                aggregateStatus: .migrated,          // placeholder — filled below
                score: score,
                aggregateScore: score,               // placeholder — filled below
                fileCount: module.sourceFiles.count,
                totalLinesOfCode: linesOfCode,
                findings: findings,
                migrationIndicators: indicators,
                depth: module.depth,
                parentQualifiedName: module.parentQualifiedName,
                childQualifiedNames: []              // placeholder — filled below
            )
        }

        // Step 2 — post-process: compute childQualifiedNames, aggregateScore, aggregateStatus
        rawResults = computeAggregates(rawResults)

        return rawResults
    }

    /// Wraps a single file in a one-module result.
    public func analyzeAsModule(file: URL) -> ModuleResult {
        let findings    = analyze(file: file)
        let linesOfCode = countLines(in: [file])
        let indicators  = collectIndicators(in: [file])
        let score       = FindingComplexity.score(for: findings)
        let name        = file.deletingPathExtension().lastPathComponent
        let status: MigrationStatus = score == 0 ? .migrated : .pendingMigration
        return ModuleResult(
            name: name,
            qualifiedName: name,
            path: file.path,
            status: status,
            aggregateStatus: status,
            score: score,
            aggregateScore: score,
            fileCount: 1,
            totalLinesOfCode: linesOfCode,
            findings: findings,
            migrationIndicators: indicators,
            depth: 0,
            parentQualifiedName: nil,
            childQualifiedNames: []
        )
    }

    // MARK: - Aggregate computation

    /// Post-processing pass: fills `childQualifiedNames`, `aggregateScore`, `aggregateStatus`
    /// for every module. Works bottom-up so children are resolved before parents.
    private func computeAggregates(_ modules: [ModuleResult]) -> [ModuleResult] {
        // Index by qualifiedName for O(1) lookup
        var byName: [String: ModuleResult] = Dictionary(
            uniqueKeysWithValues: modules.map { ($0.qualifiedName, $0) }
        )

        // Build direct-child lists
        var childMap: [String: [String]] = [:]
        for module in modules {
            if let parent = module.parentQualifiedName {
                childMap[parent, default: []].append(module.qualifiedName)
            }
        }

        // Compute aggregateScore bottom-up (process deepest modules first)
        let sorted = modules.sorted { $0.depth > $1.depth }  // deepest first
        for module in sorted {
            let children = childMap[module.qualifiedName] ?? []
            let childrenAggScore = children.compactMap { byName[$0]?.aggregateScore }.reduce(0, +)
            let aggScore = module.score + childrenAggScore
            let aggStatus: MigrationStatus = aggScore > 0 ? .pendingMigration : .migrated

            byName[module.qualifiedName] = ModuleResult(
                name: module.name,
                qualifiedName: module.qualifiedName,
                path: module.path,
                status: module.status,
                aggregateStatus: aggStatus,
                score: module.score,
                aggregateScore: aggScore,
                fileCount: module.fileCount,
                totalLinesOfCode: module.totalLinesOfCode,
                findings: module.findings,
                migrationIndicators: module.migrationIndicators,
                depth: module.depth,
                parentQualifiedName: module.parentQualifiedName,
                childQualifiedNames: children.sorted()
            )
        }

        // Return in original depth-first order
        return modules.compactMap { byName[$0.qualifiedName] }
    }

    // MARK: - Flat analysis

    public func analyze(files: [URL]) -> [Finding] {
        var findings: [Finding] = []
        for fileURL in files { findings.append(contentsOf: analyze(file: fileURL)) }
        return findings.sorted { ($0.file, $0.line) < ($1.file, $1.line) }
    }

    private func analyze(file: URL) -> [Finding] {
        guard let source = try? String(contentsOf: file, encoding: .utf8) else {
            print("⚠️  Could not read \(file.path)")
            return []
        }
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file.path, tree: tree)
        return rules.flatMap { $0.analyze(tree: tree, file: file.path, locationConverter: converter) }
    }

    // MARK: - Indicator collection

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
            return count + content.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        }
    }
}
