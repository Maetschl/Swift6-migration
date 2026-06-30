import ArgumentParser
import Foundation
import Swift6MigrationAnalyzerCore

// MARK: - Timing helper

private func elapsed(since start: Date) -> String {
    String(format: "%.2fs", Date().timeIntervalSince(start))
}

struct Swift6MigrationAnalyzerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift6-analyzer",
        abstract: "Analyze Swift 5 codebases for Swift 6 migration issues.",
        discussion: """
        Automatically detects modules recursively and analyzes each for Swift 6 concurrency
        migration issues. Each module receives a migration status (Migrated / Pending Migration)
        and a score:
          Score = SUM(finding × complexity weight)
        A score of 0.0 means the module is fully migrated.

        Modules are detected up to --max-depth levels deep (default: 4).
        Each file is owned exclusively by the deepest module it belongs to.

        All 21 built-in rules cover strict concurrency patterns (global mutable state,
        actor isolation, DispatchQueue, ObservableObject, NotificationCenter, etc.).
        """,
        version: ToolVersion.current
    )

    @Argument(help: "Path to the Swift project directory or file to analyze.")
    var path: String

    @Option(name: .long, help: "Comma-separated list of directory names to exclude (e.g. Tests,Mocks).")
    var exclude: String = ""

    @Option(name: .long, help: "Report format(s): markdown, json, html, sarif, xcode, diff. Repeat for multiple. Default: markdown.")
    var report: [String] = []

    @Option(name: .long, help: "Output file path or stem. If omitted, prints to stdout (single format only).")
    var output: String?

    @Option(name: .long, help: "Maximum module nesting depth to scan (default: 4, minimum: 1).")
    var maxDepth: Int = 4

    @Option(name: .long, help: "Path to the Docs/Rules/ directory for assistant mode rule documentation. Defaults to <project>/Docs/Rules/.")
    var docsPath: String?

    @Option(name: .long, help: "Path to a baseline JSON report for diff mode.")
    var baseline: String?

    @Option(name: .long, help: "Save the current run as a baseline JSON to this path.")
    var saveBaseline: String?

    @Option(name: .long, help: "Path to a .swift6-analyzer.json config file. Auto-detected at project root if not specified.")
    var config: String?

    @Flag(name: .long, help: "Include Tests and SnapshotTests directories (excluded by default).")
    var includeTests: Bool = false

    @Flag(name: .long, help: "Print per-phase and per-module timing to stderr.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Exit with code 1 if any error-severity findings are detected.")
    var failOnErrors: Bool = false

    @Flag(name: .long, help: "Suppress all informational stderr output (module summaries, timing). Errors are still printed.")
    var quiet: Bool = false

    mutating func run() async throws {
        let totalStart = Date()
        let targetURL = URL(fileURLWithPath: (path as NSString).standardizingPath)
        let fm = FileManager.default

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: targetURL.path, isDirectory: &isDirectory) else {
            print("❌ Path not found: \(targetURL.path)")
            throw ExitCode.failure
        }

        // Load config file (auto-detect at project root, or --config path)
        let resolvedConfig = loadConfig(projectRoot: isDirectory.boolValue ? targetURL : targetURL.deletingLastPathComponent())

        // Merge: CLI flags override config
        let resolvedDepth = max(1, resolvedConfig.maxDepth.map { maxDepth == 4 ? $0 : maxDepth } ?? maxDepth)
        let configExclusions = resolvedConfig.exclude ?? []
        let cliExclusions = exclude
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let additionalExclusions = Array(Set(configExclusions + cliExclusions))
        let resolvedIncludeTests = includeTests || (resolvedConfig.includeTests ?? false)

        // Resolved report formats (CLI overrides config default)
        let resolvedReports: [String] = {
            if !report.isEmpty { return report }
            if let cf = resolvedConfig.report, !cf.isEmpty { return cf }
            return ["markdown"]
        }()

        // Validate: multiple formats require --output
        if resolvedReports.count > 1 && output == nil {
            fputs("❌ Multiple --report formats require --output <path> to write files.\n", stderr)
            throw ExitCode.failure
        }

        let fileScanner = FileScanner(additionalExclusions: additionalExclusions)
        let disabledRules = resolvedConfig.disabledRules ?? []
        let severityOverrides = resolvedConfig.severityOverrides ?? [:]
        let analyzer = Analyzer(disabledRules: disabledRules, severityOverrides: severityOverrides, includeTests: resolvedIncludeTests)

        // Collect module results
        let modules: [ModuleResult]
        let projectName: String

        if isDirectory.boolValue {
            if !quiet { fputs("🔍 Detecting modules in \(targetURL.path) (max depth: \(resolvedDepth))...\n", stderr) }
            let detectStart = Date()
            let detectionProgress: (@Sendable (String) -> Void)? = verbose
                ? ({ msg in fputs("   \(msg)\n", stderr) } as @Sendable (String) -> Void)
                : nil
            let progressHandler: (@Sendable (String, Int) -> Void)? = verbose
                ? ({ name, fileCount in fputs("   🔬 \(name)  (\(fileCount) file\(fileCount == 1 ? "" : "s"))\n", stderr) } as @Sendable (String, Int) -> Void)
                : nil
            modules = await analyzer.analyzeModules(
                in: targetURL,
                fileScanner: fileScanner,
                maxDepth: resolvedDepth,
                onProgress: detectionProgress,
                onModuleStart: progressHandler
            )
            let detectTime = elapsed(since: detectStart)
            if verbose {
                fputs("⏱  detect+analyze: \(detectTime)\n", stderr)
            }
            projectName = targetURL.lastPathComponent
        } else {
            let detectStart = Date()
            modules = [analyzer.analyzeAsModule(file: targetURL)]
            let detectTime = elapsed(since: detectStart)
            if verbose {
                fputs("⏱  analyze (single file): \(detectTime)\n", stderr)
            }
            projectName = targetURL.deletingPathExtension().lastPathComponent
        }

        // Print module summary to stderr (indented by depth)
        let totalFiles    = modules.reduce(0) { $0 + $1.fileCount }
        let totalFindings = modules.reduce(0) { $0 + $1.findings.count }
        let projectScore  = modules.reduce(0.0) { $0 + $1.score }
        let migratedCount = modules.filter { $0.status == .migrated }.count
        let pendingCount  = modules.filter { $0.status == .pendingMigration }.count

        if !quiet {
            fputs("📦 \(modules.count) module(s) · \(totalFiles) file(s)\n\n", stderr)

            for module in modules {
                let indent = String(repeating: "  ", count: module.depth + 1)
                let scoreStr = String(format: "%.2f", module.score)
                let ind = module.migrationIndicators
                let indicators = "actors:\(ind.actorDeclarationCount) @MainActor:\(ind.mainActorAnnotationCount) async:\(ind.asyncFunctionCount)"
                let nameDisplay = module.qualifiedName.padding(toLength: max(30, module.qualifiedName.count + 2), withPad: " ", startingAt: 0)
                fputs("\(indent)\(module.status.icon) \(nameDisplay) score:\(scoreStr)  findings:\(module.findings.count)  [\(indicators)]\n", stderr)
            }

            fputs("\n", stderr)
            fputs("📊 Total findings: \(totalFindings)  |  Project score: \(String(format: "%.2f", projectScore))\n", stderr)
            fputs("   ✅ Migrated: \(migratedCount)  ⏳ Pending: \(pendingCount)\n", stderr)
            fputs("\n", stderr)
        }

        // Save baseline if requested
        if let saveBaselinePath = saveBaseline ?? resolvedConfig.saveBaseline {
            let baselineURL = URL(fileURLWithPath: (saveBaselinePath as NSString).standardizingPath)
            let encoded = try JSONEncoder().encode(modules)
            try encoded.write(to: baselineURL)
            if !quiet { fputs("💾 Baseline saved to \(baselineURL.path)\n", stderr) }
        }

        // Generate report(s)
        let reportStart = Date()
        let resolvedDocsURL: URL? = {
            if let dp = docsPath { return URL(fileURLWithPath: (dp as NSString).standardizingPath) }
            if isDirectory.boolValue { return targetURL.appendingPathComponent("Docs/Rules") }
            return nil
        }()

        for format in resolvedReports {
            let reporter = makeReporter(format: format.lowercased(), docsURL: resolvedDocsURL)
            let reportContent: String

            if format.lowercased() == "diff" {
                reportContent = try generateDiffReport(
                    modules: modules,
                    projectName: projectName,
                    baselinePath: baseline ?? resolvedConfig.baseline
                )
            } else {
                reportContent = reporter.generate(modules: modules, projectName: projectName)
            }

            if let outputStem = output {
                let ext = fileExtension(for: format.lowercased())
                let outputPath = resolvedReports.count == 1 ? outputStem : "\(outputStem).\(ext)"
                let outputURL = URL(fileURLWithPath: (outputPath as NSString).standardizingPath)
                try reportContent.write(to: outputURL, atomically: true, encoding: .utf8)
                if !quiet { fputs("✅ \(format) report written to \(outputURL.path)\n", stderr) }
            } else {
                print(reportContent)
            }
        }

        let reportTime = elapsed(since: reportStart)

        if verbose {
            fputs("⏱  report generation: \(reportTime)\n", stderr)
        }
        if !quiet { fputs("⏱  total: \(elapsed(since: totalStart))\n", stderr) }

        if failOnErrors {
            let allFindings = modules.flatMap { $0.findings }
            let errorCount = allFindings.filter { $0.severity == .error }.count
            if errorCount > 0 {
                fputs("❌ --fail-on-errors: \(errorCount) error-severity finding(s) detected.\n", stderr)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Helpers

    private func makeReporter(format: String, docsURL: URL?) -> any Reporter {
        switch format {
        case "json":      return JSONReporter()
        case "html":      return HTMLReporter()
        case "sarif":     return SARIFReporter()
        case "xcode":     return XcodeReporter()
        case "assistant": return AssistantReporter(docsPath: docsURL)
        default:          return MarkdownReporter()
        }
    }

    private func fileExtension(for format: String) -> String {
        switch format {
        case "json", "sarif": return format
        case "html":          return "html"
        case "xcode":         return "txt"
        case "diff":          return "md"
        default:              return "md"
        }
    }

    private func generateDiffReport(modules: [ModuleResult], projectName: String, baselinePath: String?) throws -> String {
        guard let path = baselinePath else {
            fputs("⚠️  --report diff requires --baseline <file>. Falling back to markdown.\n", stderr)
            return MarkdownReporter().generate(modules: modules, projectName: projectName)
        }
        let baselineURL = URL(fileURLWithPath: (path as NSString).standardizingPath)
        let data = try Data(contentsOf: baselineURL)
        let baselineModules = try JSONDecoder().decode([ModuleResult].self, from: data)
        let diff = BaselineComparator().compare(baseline: baselineModules, current: modules)
        return DiffReporter().generate(diff: diff, projectName: projectName)
    }

    /// Auto-detects `.swift6-analyzer.json` at `projectRoot`, or loads from `--config` path.
    private func loadConfig(projectRoot: URL) -> AnalyzerConfig {
        let configURL: URL
        if let configPath = config {
            configURL = URL(fileURLWithPath: (configPath as NSString).standardizingPath)
        } else {
            configURL = projectRoot.appendingPathComponent(".swift6-analyzer.json")
        }
        guard let data = try? Data(contentsOf: configURL),
              let cfg = try? JSONDecoder().decode(AnalyzerConfig.self, from: data) else {
            return AnalyzerConfig()
        }
        fputs("⚙️  Config loaded from \(configURL.path)\n", stderr)
        return cfg
    }
}
