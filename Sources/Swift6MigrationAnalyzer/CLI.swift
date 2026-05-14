import ArgumentParser
import Foundation
import Swift6MigrationAnalyzerCore

// MARK: - Timing helper

private func elapsed(since start: Date) -> String {
    String(format: "%.2fs", Date().timeIntervalSince(start))
}

struct Swift6MigrationAnalyzerCommand: ParsableCommand {
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

        All 16 built-in rules cover strict concurrency patterns (global mutable state,
        actor isolation, DispatchQueue, ObservableObject, NotificationCenter, etc.).
        """
    )

    @Argument(help: "Path to the Swift project directory or file to analyze.")
    var path: String

    @Option(name: .long, help: "Comma-separated list of directory names to exclude (e.g. Tests,Mocks).")
    var exclude: String = ""

    @Option(name: .long, help: "Report format: markdown, json, or html. Default: markdown.")
    var report: String = "markdown"

    @Option(name: .long, help: "Output file path. If omitted, prints to stdout.")
    var output: String?

    @Option(name: .long, help: "Maximum module nesting depth to scan (default: 4, minimum: 1).")
    var maxDepth: Int = 4

    @Option(name: .long, help: "Path to the Docs/Rules/ directory for assistant mode rule documentation. Defaults to <project>/Docs/Rules/.")
    var docsPath: String?

    @Flag(name: .long, help: "Print per-phase and per-module timing to stderr.")
    var verbose: Bool = false

    mutating func run() throws {
        let totalStart = Date()
        let targetURL = URL(fileURLWithPath: (path as NSString).standardizingPath)
        let fm = FileManager.default

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: targetURL.path, isDirectory: &isDirectory) else {
            print("❌ Path not found: \(targetURL.path)")
            throw ExitCode.failure
        }

        let resolvedDepth = max(1, maxDepth)
        let additionalExclusions = exclude
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let fileScanner = FileScanner(additionalExclusions: additionalExclusions)
        let analyzer = Analyzer()

        // Collect module results
        let modules: [ModuleResult]
        let projectName: String

        if isDirectory.boolValue {
            fputs("🔍 Detecting modules in \(targetURL.path) (max depth: \(resolvedDepth))...\n", stderr)
            let detectStart = Date()
            let detectionProgress: ((String) -> Void)? = verbose ? { msg in
                fputs("   \(msg)\n", stderr)
            } : nil
            let progressHandler: ((String, Int) -> Void)? = verbose ? { name, fileCount in
                fputs("   🔬 \(name)  (\(fileCount) file\(fileCount == 1 ? "" : "s"))\n", stderr)
            } : nil
            modules = analyzer.analyzeModules(
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

        // Generate report
        let reportStart = Date()
        let reporter: any Reporter
        switch report.lowercased() {
        case "json":
            reporter = JSONReporter()
        case "html":
            reporter = HTMLReporter()
        case "assistant":
            let resolvedDocsURL: URL? = {
                if let dp = docsPath {
                    return URL(fileURLWithPath: (dp as NSString).standardizingPath)
                }
                // Default: <analyzed-dir>/Docs/Rules/
                if isDirectory.boolValue {
                    return targetURL.appendingPathComponent("Docs/Rules")
                }
                return nil
            }()
            reporter = AssistantReporter(docsPath: resolvedDocsURL)
        default:
            reporter = MarkdownReporter()
        }

        let reportContent = reporter.generate(modules: modules, projectName: projectName)
        let reportTime = elapsed(since: reportStart)

        if let outputPath = output {
            let outputURL = URL(fileURLWithPath: (outputPath as NSString).standardizingPath)
            try reportContent.write(to: outputURL, atomically: true, encoding: .utf8)
            fputs("✅ Report written to \(outputURL.path)\n", stderr)
        } else {
            print(reportContent)
        }

        if verbose {
            fputs("⏱  report generation: \(reportTime)\n", stderr)
        }
        fputs("⏱  total: \(elapsed(since: totalStart))\n", stderr)
    }
}
