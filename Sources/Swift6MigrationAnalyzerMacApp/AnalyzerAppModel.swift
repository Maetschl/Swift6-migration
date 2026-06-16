import AppKit
import Foundation
import Observation
import Swift6MigrationAnalyzerCore
import UniformTypeIdentifiers

enum SeverityFilter: String, CaseIterable, Identifiable {
    case all
    case error
    case warning
    case info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .error: return "Errors"
        case .warning: return "Warnings"
        case .info: return "Info"
        }
    }

    func contains(_ severity: Severity) -> Bool {
        switch self {
        case .all: return true
        case .error: return severity == .error
        case .warning: return severity == .warning
        case .info: return severity == .info
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case json
    case html

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .html: return "HTML"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .json: return "json"
        case .html: return "html"
        }
    }

    var contentType: UTType {
        switch self {
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .json: return .json
        case .html: return .html
        }
    }
}

struct AnalysisSummary: Sendable {
    let projectScore: Double
    let moduleCount: Int
    let migratedCount: Int
    let totalFindings: Int
    let totalErrors: Int
    let totalWarnings: Int
    let totalFiles: Int
    let totalLines: Int

    static let empty = AnalysisSummary(
        projectScore: 0,
        moduleCount: 0,
        migratedCount: 0,
        totalFindings: 0,
        totalErrors: 0,
        totalWarnings: 0,
        totalFiles: 0,
        totalLines: 0
    )
}

private struct AnalysisOptions: Sendable {
    let targetURL: URL
    let maxDepth: Int
    let includeTests: Bool
}

private struct AnalysisRun: Sendable {
    let modules: [ModuleResult]
    let duration: TimeInterval
}

@MainActor
@Observable
final class AnalyzerAppModel {
    var selectedURL: URL?
    var maxDepth = 4
    var includeTests = false
    var isAnalyzing = false
    var modules: [ModuleResult] = []
    var selectedModuleQualifiedName: String?
    var selectedSeverity: SeverityFilter = .all
    var searchText = ""
    var statusMessage = "Choose a Swift project to begin."
    var errorMessage: String?
    var lastRunDate: Date?
    var lastRunDuration: TimeInterval?

    var canAnalyze: Bool {
        selectedURL != nil && !isAnalyzing
    }

    var projectName: String {
        selectedURL?.lastPathComponent ?? "No Project"
    }

    var summary: AnalysisSummary {
        guard !modules.isEmpty else { return .empty }
        let findings = allFindings
        return AnalysisSummary(
            projectScore: modules.filter { $0.depth == 0 }.reduce(0.0) { $0 + $1.aggregateScore },
            moduleCount: modules.count,
            migratedCount: modules.filter { $0.aggregateStatus.isMigrated }.count,
            totalFindings: findings.count,
            totalErrors: findings.filter { $0.severity == .error }.count,
            totalWarnings: findings.filter { $0.severity == .warning }.count,
            totalFiles: modules.reduce(0) { $0 + $1.fileCount },
            totalLines: modules.reduce(0) { $0 + $1.totalLinesOfCode }
        )
    }

    var allFindings: [Finding] {
        modules.flatMap(\.findings)
    }

    var filteredFindings: [Finding] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allFindings.filter { finding in
            guard selectedSeverity.contains(finding.severity) else { return false }
            guard !query.isEmpty else { return true }
            return finding.rule.lowercased().contains(query)
                || finding.message.lowercased().contains(query)
                || displayPath(finding.file).lowercased().contains(query)
        }
    }

    var selectedModule: ModuleResult? {
        if let selectedModuleQualifiedName,
           let module = modules.first(where: { $0.qualifiedName == selectedModuleQualifiedName }) {
            return module
        }
        return modules.first
    }

    func chooseProject() {
        let panel = NSOpenPanel()
        panel.title = "Choose Swift Project"
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        if panel.runModal() == .OK, let url = panel.url {
            selectedURL = url
            modules = []
            selectedModuleQualifiedName = nil
            searchText = ""
            errorMessage = nil
            lastRunDate = nil
            lastRunDuration = nil
            statusMessage = "Ready to analyze \(url.lastPathComponent)."
        }
    }

    func analyzeSelectedProject() {
        guard let selectedURL else {
            chooseProject()
            return
        }

        let options = AnalysisOptions(
            targetURL: selectedURL,
            maxDepth: max(1, maxDepth),
            includeTests: includeTests
        )

        isAnalyzing = true
        errorMessage = nil
        statusMessage = "Analyzing \(selectedURL.lastPathComponent)..."

        Task { @MainActor in
            let run = await Self.runAnalysis(options: options)
            modules = run.modules
            selectedModuleQualifiedName = run.modules.first?.qualifiedName
            lastRunDate = Date()
            lastRunDuration = run.duration
            statusMessage = "Analysis complete: \(run.modules.count) modules in \(Self.formatDuration(run.duration))."
            isAnalyzing = false
        }
    }

    func export(format: ExportFormat) {
        guard !modules.isEmpty else {
            errorMessage = "Run an analysis before exporting a report."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export \(format.title) Report"
        panel.nameFieldStringValue = "\(projectName)-swift6-report.\(format.fileExtension)"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            let content = reportContent(format: format)
            try content.write(to: destinationURL, atomically: true, encoding: .utf8)
            statusMessage = "Exported \(format.title) report to \(destinationURL.lastPathComponent)."
        } catch {
            errorMessage = "Could not export report: \(error.localizedDescription)"
        }
    }

    func displayPath(_ path: String) -> String {
        guard let selectedURL else { return path }
        let root = selectedURL.standardizedFileURL.path
        guard path.hasPrefix(root) else { return path }
        var relative = String(path.dropFirst(root.count))
        if relative.hasPrefix("/") {
            relative.removeFirst()
        }
        return relative.isEmpty ? selectedURL.lastPathComponent : relative
    }

    private func reportContent(format: ExportFormat) -> String {
        switch format {
        case .markdown:
            return MarkdownReporter().generate(modules: modules, projectName: projectName)
        case .json:
            return JSONReporter().generate(modules: modules, projectName: projectName)
        case .html:
            return HTMLReporter().generate(modules: modules, projectName: projectName)
        }
    }

    nonisolated private static func runAnalysis(options: AnalysisOptions) async -> AnalysisRun {
        await Task.detached(priority: .userInitiated) {
            let start = Date()
            let isDirectory = (try? options.targetURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let analyzer = Analyzer(includeTests: options.includeTests)

            let modules: [ModuleResult]
            if isDirectory {
                modules = analyzer.analyzeModules(
                    in: options.targetURL,
                    fileScanner: FileScanner(),
                    maxDepth: options.maxDepth
                )
            } else {
                modules = [analyzer.analyzeAsModule(file: options.targetURL)]
            }

            return AnalysisRun(
                modules: modules,
                duration: Date().timeIntervalSince(start)
            )
        }.value
    }

    nonisolated static func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.2fs", duration)
    }
}
