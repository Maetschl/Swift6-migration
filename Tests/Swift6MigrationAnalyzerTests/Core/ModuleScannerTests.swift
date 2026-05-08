import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("ModuleScanner")
struct ModuleScannerTests {

    private let fileScanner = FileScanner()

    // MARK: - Strategy 1: Multi-package workspace

    @Test("Detects multiple packages when each subdir has Package.swift")
    func detectsMultiPackageWorkspace() throws {
        let root = try makeTempDir("MultiPkg", structure: [
            "PackageA/Package.swift": "// swift-tools-version: 5.9",
            "PackageA/Sources/A.swift": "let a = 1",
            "PackageB/Package.swift": "// swift-tools-version: 5.9",
            "PackageB/Sources/B.swift": "let b = 2"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner)
        let modules = scanner.detectModules(in: root)
        let names = modules.map(\.name).sorted()
        #expect(names == ["PackageA", "PackageB"])
    }

    // MARK: - Strategy 2: Single SPM package with multiple targets

    @Test("Detects SPM targets as modules under Sources/")
    func detectsSPMTargets() throws {
        let root = try makeTempDir("SPMPkg", structure: [
            "Package.swift": "// swift-tools-version: 5.9",
            "Sources/CoreModule/Core.swift": "struct Core { }",
            "Sources/UIModule/View.swift": "struct View { }",
            "Sources/NetworkModule/Client.swift": "struct Client { }"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner)
        let modules = scanner.detectModules(in: root)
        let names = modules.map(\.name).sorted()
        #expect(names.count == 3)
        #expect(names.contains("CoreModule"))
        #expect(names.contains("UIModule"))
        #expect(names.contains("NetworkModule"))
    }

    // MARK: - Strategy 3: Modular directory layout

    @Test("Detects subdirectories as modules when no Package.swift present")
    func detectsSubdirModules() throws {
        let root = try makeTempDir("DirModules", structure: [
            "FeatureA/ViewA.swift": "let a = 1",
            "FeatureB/ViewB.swift": "let b = 2",
            "FeatureC/ViewC.swift": "let c = 3"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner)
        let modules = scanner.detectModules(in: root)
        #expect(modules.count == 3)
    }

    // MARK: - Strategy 4: Single non-modular project

    @Test("Treats project as a single module when all files are at the root")
    func detectsSingleModule() throws {
        let root = try makeTempDir("SingleMod", structure: [
            "App.swift": "let a = 1",
            "Model.swift": "struct M { }",
            "View.swift": "struct V { }"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner)
        let modules = scanner.detectModules(in: root)
        #expect(modules.count == 1)
        // The module name equals the root directory's last path component
        #expect(modules[0].name == root.lastPathComponent)
        #expect(modules[0].sourceFiles.count == 3)
    }

    @Test("Single file results in one module")
    func singleFileIsSingleModule() throws {
        let root = try makeTempDir("OneFile", structure: [
            "Main.swift": "print(\"hello\")"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner)
        let modules = scanner.detectModules(in: root)
        #expect(modules.count == 1)
    }

    // MARK: - Source file counts

    @Test("Each module contains only its own source files")
    func moduleContainsOnlyItsOwnFiles() throws {
        let root = try makeTempDir("Isolated", structure: [
            "Alpha/A1.swift": "let a1 = 1",
            "Alpha/A2.swift": "let a2 = 2",
            "Beta/B1.swift": "let b1 = 3"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner)
        let modules = scanner.detectModules(in: root).sorted { $0.name < $1.name }
        let alpha = modules.first { $0.name == "Alpha" }
        let beta  = modules.first { $0.name == "Beta" }
        #expect(alpha?.sourceFiles.count == 2)
        #expect(beta?.sourceFiles.count == 1)
    }

    // MARK: - Helpers

    private func makeTempDir(_ name: String, structure: [String: String]) throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ModuleScannerTmp_\(name)")
        try? FileManager.default.removeItem(at: base)
        for (relativePath, content) in structure {
            let fileURL = base.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return base
    }
}
