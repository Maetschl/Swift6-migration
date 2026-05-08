import ArgumentParser
import Foundation
import Swift6MigrationAnalyzerCore


struct Swift6MigrationAnalyzerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift6-analyzer",
        abstract: "Analyze Swift 5 codebases for Swift 6 migration issues.",
        discussion: """
        Automatically detects modules and analyzes each for Swift 6 concurrency migration issues.
        Each module receives a migration status (Migrated / Pending Migration) and a score:
          Score = SUM(finding × complexity weight)
        A score of 0.0 means the module is fully migrated.

        Default rules cover strict concurrency patterns (global mutable state,
        actor isolation, DispatchQueue, ObservableObject, NotificationCenter, etc.).
        Use --include-quality-rules to also flag force-unwrap and force-try.
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

    @Flag(name: .long, help: "Also include code-quality rules (ForceUnwrap, ForceTry) — not Swift 6 specific.")
    var includeQualityRules: Bool = false

    mutating func run() throws {
        let targetURL = URL(fileURLWithPath: (path as NSString).standardizingPath)
        let fm = FileManager.default

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: targetURL.path, isDirectory: &isDirectory) else {
            print("❌ Path not found: \(targetURL.path)")
            throw ExitCode.failure
        }

        let additionalExclusions = exclude
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let fileScanner = FileScanner(additionalExclusions: additionalExclusions)
        let rules: [any Rule] = includeQualityRules ? Analyzer.allRules : Analyzer.defaultRules
        let analyzer = Analyzer(rules: rules)

        // Collect module results
        let modules: [ModuleResult]
        let projectName: String

        if isDirectory.boolValue {
            fputs("🔍 Detecting modules in \(targetURL.path)...\n", stderr)
            modules = analyzer.analyzeModules(in: targetURL, fileScanner: fileScanner)
            projectName = targetURL.lastPathComponent
        } else {
            modules = [analyzer.analyzeAsModule(file: targetURL)]
            projectName = targetURL.deletingPathExtension().lastPathComponent
        }

        // Print module summary to stderr
        let totalFiles    = modules.reduce(0) { $0 + $1.fileCount }
        let totalFindings = modules.reduce(0) { $0 + $1.findings.count }
        let projectScore  = modules.reduce(0.0) { $0 + $1.score }
        let migratedCount = modules.filter { $0.status == .migrated }.count
        let pendingCount  = modules.filter { $0.status == .pendingMigration }.count

        fputs("📦 \(modules.count) module(s) · \(totalFiles) file(s)\n\n", stderr)

        for module in modules {
            let scoreStr = String(format: "%.2f", module.score)
            let ind = module.migrationIndicators
            let indicators = "actors:\(ind.actorDeclarationCount) @MainActor:\(ind.mainActorAnnotationCount) async:\(ind.asyncFunctionCount)"
            fputs("  \(module.status.icon) \(module.name.padding(toLength: 30, withPad: " ", startingAt: 0)) score:\(scoreStr)  findings:\(module.findings.count)  [\(indicators)]\n", stderr)
        }

        fputs("\n", stderr)
        fputs("📊 Total findings: \(totalFindings)  |  Project score: \(String(format: "%.2f", projectScore))\n", stderr)
        fputs("   ✅ Migrated: \(migratedCount)  ⏳ Pending: \(pendingCount)\n", stderr)
        if includeQualityRules {
            fputs("   ℹ️  Code-quality rules enabled (--include-quality-rules)\n", stderr)
        }
        fputs("\n", stderr)

        // Generate report
        let reporter: any Reporter
        switch report.lowercased() {
        case "json":
            reporter = JSONReporter()
        case "html":
            reporter = HTMLReporter()
        default:
            reporter = MarkdownReporter()
        }

        let reportContent = reporter.generate(modules: modules, projectName: projectName)

        if let outputPath = output {
            let outputURL = URL(fileURLWithPath: (outputPath as NSString).standardizingPath)
            try reportContent.write(to: outputURL, atomically: true, encoding: .utf8)
            fputs("✅ Report written to \(outputURL.path)\n", stderr)
        } else {
            print(reportContent)
        }
    }
}
