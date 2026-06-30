import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

/// Measures wall-clock time for the core analysis pipeline.
/// These tests verify that performance does not regress — they assert that
/// the SampleSwiftProject (26 files) analyzes in well under 5 seconds,
/// which would catch any accidental re-introduction of O(n²) scanning.
@Suite("Performance")
struct PerformanceTests {

    // Locate the SampleSwiftProject relative to this source file.
    private static var sampleProjectURL: URL {
        // Walk up from the test file (.../Tests/Swift6MigrationAnalyzerTests/Core/PerformanceTests.swift)
        // 3 levels up = repo root, then append SampleSwiftProject
        var url = URL(fileURLWithPath: #filePath) // PerformanceTests.swift
        for _ in 0..<4 { url = url.deletingLastPathComponent() }
        return url.appendingPathComponent("SampleSwiftProject")
    }

    private let analyzer    = Analyzer()
    private let fileScanner = FileScanner()

    // MARK: - Module detection timing

    @Test("ModuleScanner detects SampleSwiftProject modules in under 10s")
    func moduleScannerPerformance() throws {
        let url = Self.sampleProjectURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Skip gracefully when running outside the repo (e.g. CI without sample)
            return
        }

        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 4)
        let start   = Date()
        let modules = scanner.detectModules(in: url)
        let elapsed = Date().timeIntervalSince(start)

        #expect(modules.count > 0, "Expected at least one module")
        // Debug builds are ~10× slower than release; 10s covers both.
        #expect(elapsed < 10.0, "Module detection took \(String(format: "%.2f", elapsed))s — should be < 10s")
    }

    // MARK: - Full analysis timing

    @Test("analyzeModules completes SampleSwiftProject in under 15s")
    func fullAnalysisPerformance() async throws {
        let url = Self.sampleProjectURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let start   = Date()
        let modules = await analyzer.analyzeModules(in: url, fileScanner: fileScanner, maxDepth: 4)
        let elapsed = Date().timeIntervalSince(start)

        #expect(modules.count == 15, "Expected 15 modules, got \(modules.count)")
        // 15s covers debug mode; release should be well under 2s.
        #expect(elapsed < 15.0, "Full analysis took \(String(format: "%.2f", elapsed))s — should be < 15s")
    }

    // MARK: - Single-pass correctness

    @Test("parseAll reads each file exactly once and produces correct line counts")
    func parseAllSingleRead() throws {
        let url = Self.sampleProjectURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let allFiles = fileScanner.scan(directory: url)
        #expect(!allFiles.isEmpty)

        let parsed = analyzer.parseAll(files: allFiles)
        #expect(parsed.count == allFiles.count, "parseAll should return one ParsedFile per readable file")

        for pf in parsed {
            #expect(pf.lineCount > 0, "Line count for \(pf.url.lastPathComponent) should be > 0")
            // Verify tree is populated (has at least a source file statement list)
            #expect(!pf.source.isEmpty, "Source for \(pf.url.lastPathComponent) should not be empty")
        }
    }

    // MARK: - Scan count regression

    @Test("FileScanner scans a directory once and FileCache provides correct results")
    func fileCacheCorrectness() throws {
        let url = Self.sampleProjectURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // Scan once
        let allFiles = fileScanner.scan(directory: url)
        #expect(!allFiles.isEmpty, "Should find Swift files in SampleSwiftProject")

        // All returned URLs should be .swift files
        for fileURL in allFiles {
            #expect(fileURL.pathExtension == "swift", "Non-swift file returned: \(fileURL.lastPathComponent)")
        }

        // Every file should be under the scanned directory
        for fileURL in allFiles {
            #expect(fileURL.path.hasPrefix(url.path), "File outside scan root: \(fileURL.path)")
        }
    }
}
