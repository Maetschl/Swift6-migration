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
            MainActorRunRule(),
            NotificationCenterRule(),
            OperationQueueMainRule(),
            TimerRule(),
            CombineRule(),
            ThreadRule(),
            CheckedContinuationRule(),
        ]
    }

    // MARK: - Module-aware analysis

    /// Detects modules recursively up to `maxDepth`, analyzes each, and returns
    /// results in depth-first tree order with aggregate scores and child lists computed.
    ///
    /// - Parameter onProgress: Optional callback for progress events during both detection
    ///   and analysis phases. Receives a human-readable message.
    /// - Parameter onModuleStart: Optional callback invoked just before each module is analyzed.
    ///   Receives the module's qualified name and source file count.
    public func analyzeModules(
        in directory: URL,
        fileScanner: FileScanner,
        maxDepth: Int = 4,
        onProgress: ((String) -> Void)? = nil,
        onModuleStart: ((String, Int) -> Void)? = nil
    ) -> [ModuleResult] {
        let moduleScanner = ModuleScanner(fileScanner: fileScanner, maxDepth: maxDepth)
        let modules = moduleScanner.detectModules(in: directory, onProgress: onProgress)

        // Step 1 — build raw results using single-pass per file
        var rawResults: [ModuleResult] = modules.map { module in
            onModuleStart?(module.qualifiedName, module.sourceFiles.count)
            let parsed      = parseAll(files: module.sourceFiles)
            let findings    = analyzeparsed(parsed)
            let linesOfCode = parsed.reduce(0) { $0 + $1.lineCount }
            let indicators  = collectIndicatorsParsed(parsed)
            let score       = FindingComplexity.errorScore(for: findings)
            let ownStatus   = buildStatus(score: score, findings: findings)
            return ModuleResult(
                name: module.name,
                qualifiedName: module.qualifiedName,
                path: module.rootURL.path,
                status: ownStatus,
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
        guard let source = try? String(contentsOf: file, encoding: .utf8) else {
            print("⚠️  Could not read \(file.path)")
            return ModuleResult(
                name: file.lastPathComponent, qualifiedName: file.lastPathComponent,
                path: file.path, status: .migrated, aggregateStatus: .migrated,
                score: 0, aggregateScore: 0, fileCount: 0, totalLinesOfCode: 0,
                findings: [], migrationIndicators: .empty, depth: 0,
                parentQualifiedName: nil, childQualifiedNames: []
            )
        }
        let parsed      = ParsedFile(url: file, source: source)
        let findings    = analyzeparsed([parsed])
        let indicators  = collectIndicatorsParsed([parsed])
        let score       = FindingComplexity.errorScore(for: findings)
        let name        = file.deletingPathExtension().lastPathComponent
        let status      = buildStatus(score: score, findings: findings)
        return ModuleResult(
            name: name,
            qualifiedName: name,
            path: file.path,
            status: status,
            aggregateStatus: status,
            score: score,
            aggregateScore: score,
            fileCount: 1,
            totalLinesOfCode: parsed.lineCount,
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

        // Compute aggregates bottom-up (process deepest modules first)
        let sorted = modules.sorted { $0.depth > $1.depth }  // deepest first
        for module in sorted {
            let children = childMap[module.qualifiedName] ?? []
            let childrenAggScore    = children.compactMap { byName[$0]?.aggregateScore }.reduce(0, +)
            let childrenAggFindings = children.compactMap { byName[$0]?.aggregateFindings }.reduce(0, +)
            let childrenAggInd      = children.compactMap { byName[$0]?.aggregateMigrationIndicators }
                                              .reduce(MigrationIndicators.empty, +)
            let aggScore    = module.score + childrenAggScore
            let aggFindings = module.findings.count + childrenAggFindings
            let aggInd      = module.migrationIndicators + childrenAggInd
            let childrenHaveWarnings = children.compactMap { byName[$0]?.aggregateStatus.hasWarnings }.contains(true)
            let aggHasWarnings = module.status.hasWarnings || childrenHaveWarnings
            var aggTags: Set<MigrationTag> = aggScore > 0 ? [.pendingMigration] : [.migrated]
            if aggHasWarnings { aggTags.insert(.warnings) }
            let aggStatus = MigrationStatus(aggTags)

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
                childQualifiedNames: children.sorted(),
                aggregateFindings: aggFindings,
                aggregateMigrationIndicators: aggInd
            )
        }

        // Return in original depth-first order
        return modules.compactMap { byName[$0.qualifiedName] }
    }


    private func buildStatus(score: Double, findings: [Finding]) -> MigrationStatus {
        let hasWarnings = findings.contains { $0.severity == .warning || $0.severity == .info }
        var tags: Set<MigrationTag> = score == 0 ? [.migrated] : [.pendingMigration]
        if hasWarnings { tags.insert(.warnings) }
        return MigrationStatus(tags)
    }

    // MARK: - Single-pass file parsing

    /// Reads and parses every file exactly once. Files that cannot be read are skipped.
    func parseAll(files: [URL]) -> [ParsedFile] {
        files.compactMap { url in
            guard let source = try? String(contentsOf: url, encoding: .utf8) else {
                fputs("⚠️  Could not read \(url.path)\n", stderr)
                return nil
            }
            return ParsedFile(url: url, source: source)
        }
    }

    /// Runs all rules over pre-parsed files (no extra I/O or re-parse).
    func analyzeparsed(_ parsed: [ParsedFile]) -> [Finding] {
        var findings: [Finding] = []
        for pf in parsed {
            let converter = SourceLocationConverter(fileName: pf.url.path, tree: pf.tree)
            let raw = rules.flatMap {
                $0.analyze(tree: pf.tree, file: pf.url.path, locationConverter: converter)
            }
            let filtered = SuppressionFilter.filter(findings: raw, source: pf.source)
            findings.append(contentsOf: filtered)
        }
        return findings.sorted { ($0.file, $0.line) < ($1.file, $1.line) }
    }

    /// Collects migration indicators from pre-parsed files.
    func collectIndicatorsParsed(_ parsed: [ParsedFile]) -> MigrationIndicators {
        var total = MigrationIndicatorCollector()
        for pf in parsed {
            let collector = MigrationIndicatorCollector()
            collector.walk(pf.tree)
            total = MigrationIndicatorCollector.merge(total, collector)
        }
        return total.build()
    }

    // MARK: - Legacy flat helpers (kept for external callers / tests)

    public func analyze(files: [URL]) -> [Finding] {
        analyzeparsed(parseAll(files: files))
    }
}
