import Foundation
import SwiftParser
import SwiftSyntax

public struct Analyzer: Sendable {
    private let rules: [any Rule]
    private let includeTests: Bool

    /// - Parameters:
    ///   - rules: Full rule set. Defaults to `Self.defaultRules`.
    ///   - disabledRules: Rule names to skip entirely.
    ///   - severityOverrides: Map of rule name → override severity string ("error","warning","info").
    ///   - includeTests: When true, test directories are not excluded from module detection.
    public init(
        rules: [any Rule] = Self.defaultRules,
        disabledRules: [String] = [],
        severityOverrides: [String: String] = [:],
        includeTests: Bool = false
    ) {
        let active = rules.filter { !disabledRules.contains($0.name) }
        if severityOverrides.isEmpty {
            self.rules = active
        } else {
            self.rules = active.map { rule in
                guard let raw = severityOverrides[rule.name],
                      let sev = Severity(rawValue: raw) else { return rule }
                return SeverityOverrideRule(wrapped: rule, overrideSeverity: sev) as any Rule
            }
        }
        self.includeTests = includeTests
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
            ActorReentrancyRule(),
            WithUnsafeCurrentTaskRule(),
            AsyncSequenceRule(),
        ]
    }

    // MARK: - Module-aware analysis

    /// Detects modules recursively up to `maxDepth`, analyzes each **in parallel** using
    /// Swift structured concurrency (`withTaskGroup`), and returns results in depth-first
    /// tree order with aggregate scores and child lists computed.
    ///
    /// - Parameter onProgress: Optional callback for progress events during both detection
    ///   and analysis phases. Receives a human-readable message.
    /// - Parameter onModuleStart: Optional callback invoked just before each module is analyzed.
    ///   Receives the module's qualified name and source file count.
    public func analyzeModules(
        in directory: URL,
        fileScanner: FileScanner,
        maxDepth: Int = 4,
        onProgress: (@Sendable (String) -> Void)? = nil,
        onModuleStart: (@Sendable (String, Int) -> Void)? = nil
    ) async -> [ModuleResult] {
        let moduleScanner = ModuleScanner(fileScanner: fileScanner, maxDepth: maxDepth, includeTests: includeTests)
        let modules = moduleScanner.detectModules(in: directory, onProgress: onProgress)

        // Parallel analysis using Swift structured concurrency.
        // Each task returns its (originalIndex, ModuleResult) so we can restore original order.
        let capturedRules = self.rules
        var indexedResults: [(Int, ModuleResult)] = await withTaskGroup(
            of: (Int, ModuleResult).self
        ) { group in
            for (index, module) in modules.enumerated() {
                group.addTask {
                    onModuleStart?(module.qualifiedName, module.sourceFiles.count)
                    let parsed      = Self.parseAllStatic(files: module.sourceFiles)
                    let findings    = Self.analyzeParsedStatic(parsed, rules: capturedRules)
                    let linesOfCode = parsed.reduce(0) { $0 + $1.lineCount }
                    let indicators  = Self.collectIndicatorsParsedStatic(parsed)
                    let score       = FindingComplexity.errorScore(for: findings)
                    let ownStatus   = Self.buildStatusStatic(score: score, findings: findings)
                    let result = ModuleResult(
                        name: module.name,
                        qualifiedName: module.qualifiedName,
                        path: module.rootURL.path,
                        status: ownStatus,
                        aggregateStatus: .migrated,
                        score: score,
                        aggregateScore: score,
                        fileCount: module.sourceFiles.count,
                        totalLinesOfCode: linesOfCode,
                        findings: findings,
                        migrationIndicators: indicators,
                        depth: module.depth,
                        parentQualifiedName: module.parentQualifiedName,
                        childQualifiedNames: []
                    )
                    return (index, result)
                }
            }
            var collected: [(Int, ModuleResult)] = []
            for await pair in group { collected.append(pair) }
            return collected
        }

        // Restore depth-first order (same as the original module detection order).
        indexedResults.sort { $0.0 < $1.0 }

        // Step 2 — post-process: compute childQualifiedNames, aggregateScore, aggregateStatus
        var ordered = indexedResults.map(\.1)
        ordered = computeAggregates(ordered)
        return ordered
    }

    /// Wraps a single file in a one-module result.
    public func analyzeAsModule(file: URL) -> ModuleResult {
        guard let source = try? String(contentsOf: file, encoding: .utf8) else {
            fputs("⚠️  Could not read \(file.path)\n", stderr)
            return ModuleResult(
                name: file.lastPathComponent, qualifiedName: file.lastPathComponent,
                path: file.path, status: .migrated, aggregateStatus: .migrated,
                score: 0, aggregateScore: 0, fileCount: 0, totalLinesOfCode: 0,
                findings: [], migrationIndicators: .empty, depth: 0,
                parentQualifiedName: nil, childQualifiedNames: []
            )
        }
        let parsed      = ParsedFile(url: file, source: source)
        let findings    = analyzeParsed([parsed])
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
            let childrenAggFiles    = children.compactMap { byName[$0]?.aggregateFileCount }.reduce(0, +)
            let childrenAggLines    = children.compactMap { byName[$0]?.aggregateLinesOfCode }.reduce(0, +)
            let aggScore    = module.score + childrenAggScore
            let aggFindings = module.findings.count + childrenAggFindings
            let aggInd      = module.migrationIndicators + childrenAggInd
            let aggFiles    = module.fileCount + childrenAggFiles
            let aggLines    = module.totalLinesOfCode + childrenAggLines
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
                aggregateMigrationIndicators: aggInd,
                aggregateFileCount: aggFiles,
                aggregateLinesOfCode: aggLines
            )
        }

        // Return in original depth-first order
        return modules.compactMap { byName[$0.qualifiedName] }
    }


    private func buildStatus(score: Double, findings: [Finding]) -> MigrationStatus {
        Self.buildStatusStatic(score: score, findings: findings)
    }

    private static func buildStatusStatic(score: Double, findings: [Finding]) -> MigrationStatus {
        let hasWarnings = findings.contains { $0.severity == .warning || $0.severity == .info }
        var tags: Set<MigrationTag> = score == 0 ? [.migrated] : [.pendingMigration]
        if hasWarnings { tags.insert(.warnings) }
        return MigrationStatus(tags)
    }

    // MARK: - Single-pass file parsing

    /// Reads and parses every file exactly once. Files that cannot be read are skipped.
    func parseAll(files: [URL]) -> [ParsedFile] {
        Self.parseAllStatic(files: files)
    }

    private static func parseAllStatic(files: [URL]) -> [ParsedFile] {
        files.compactMap { url in
            guard let source = try? String(contentsOf: url, encoding: .utf8) else {
                fputs("⚠️  Could not read \(url.path)\n", stderr)
                return nil
            }
            return ParsedFile(url: url, source: source)
        }
    }

    /// Runs all rules over pre-parsed files (no extra I/O or re-parse).
    func analyzeParsed(_ parsed: [ParsedFile]) -> [Finding] {
        Self.analyzeParsedStatic(parsed, rules: rules)
    }

    private static func analyzeParsedStatic(_ parsed: [ParsedFile], rules: [any Rule]) -> [Finding] {
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
        Self.collectIndicatorsParsedStatic(parsed)
    }

    private static func collectIndicatorsParsedStatic(_ parsed: [ParsedFile]) -> MigrationIndicators {
        parsed.reduce(MigrationIndicators.empty) { accumulated, pf in
            let collector = MigrationIndicatorCollector()
            collector.walk(pf.tree)
            return accumulated + collector.build()
        }
    }

    // MARK: - Legacy flat helpers (kept for external callers / tests)

    public func analyze(files: [URL]) -> [Finding] {
        analyzeParsed(parseAll(files: files))
    }
}

// MARK: - Severity override wrapper

/// Wraps an existing rule and overrides the severity of every finding it emits.
private struct SeverityOverrideRule: Rule {
    let wrapped: any Rule
    let overrideSeverity: Severity

    var name: String { wrapped.name }

    func analyze(tree: SourceFileSyntax, file: String, locationConverter: SourceLocationConverter) -> [Finding] {
        wrapped.analyze(tree: tree, file: file, locationConverter: locationConverter)
            .map { finding in
                Finding(
                    file: finding.file,
                    line: finding.line,
                    column: finding.column,
                    severity: overrideSeverity,
                    rule: finding.rule,
                    message: finding.message
                )
            }
    }
}
