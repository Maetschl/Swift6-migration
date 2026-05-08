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
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 1)
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
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 1)
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
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 1)
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
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 1)
        let modules = scanner.detectModules(in: root)
        #expect(modules.count == 1)
        #expect(modules[0].name == root.lastPathComponent)
        #expect(modules[0].sourceFiles.count == 3)
    }

    @Test("Single file results in one module")
    func singleFileIsSingleModule() throws {
        let root = try makeTempDir("OneFile", structure: [
            "Main.swift": "print(\"hello\")"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 1)
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
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 1)
        let modules = scanner.detectModules(in: root).sorted { $0.name < $1.name }
        let alpha = modules.first { $0.name == "Alpha" }
        let beta  = modules.first { $0.name == "Beta" }
        #expect(alpha?.sourceFiles.count == 2)
        #expect(beta?.sourceFiles.count == 1)
    }

    // MARK: - Deep scanning (multi-level)

    @Test("Detects 2-level deep modules")
    func detectsTwoLevelDeep() throws {
        let root = try makeTempDir("TwoLevel", structure: [
            "FeatureA/Sub1/S1.swift": "let s1 = 1",
            "FeatureA/Sub2/S2.swift": "let s2 = 2",
            "FeatureB/Core.swift": "let b = 3"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 4)
        let modules = scanner.detectModules(in: root)
        let qualifiedNames = modules.map(\.qualifiedName).sorted()
        // Should detect FeatureA, FeatureA/Sub1, FeatureA/Sub2, FeatureB
        #expect(qualifiedNames.contains("FeatureA"))
        #expect(qualifiedNames.contains("FeatureA/Sub1"))
        #expect(qualifiedNames.contains("FeatureA/Sub2"))
        #expect(qualifiedNames.contains("FeatureB"))
    }

    @Test("Detects 3-level deep modules")
    func detectsThreeLevelsDeep() throws {
        let root = try makeTempDir("ThreeLevel", structure: [
            "A/A1/A1a/Deep.swift": "let deep = 1",
            "A/A2/Shallow.swift": "let s = 2",
            "B/B1.swift": "let b = 3"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 4)
        let modules = scanner.detectModules(in: root)
        let qualifiedNames = Set(modules.map(\.qualifiedName))
        #expect(qualifiedNames.contains("A/A1/A1a"))
        #expect(qualifiedNames.contains("A/A2"))
        #expect(qualifiedNames.contains("B"))
    }

    @Test("maxDepth=1 stops at first level only")
    func maxDepthOneStopsAtFirstLevel() throws {
        let root = try makeTempDir("DepthLimit", structure: [
            "FeatureA/Sub1/S1.swift": "let s1 = 1",
            "FeatureA/Sub2/S2.swift": "let s2 = 2",
            "FeatureB/Core.swift": "let b = 3"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 1)
        let modules = scanner.detectModules(in: root)
        let qualifiedNames = modules.map(\.qualifiedName)
        // maxDepth=1 → only FeatureA and FeatureB; no Sub1/Sub2
        #expect(qualifiedNames.contains("FeatureA"))
        #expect(qualifiedNames.contains("FeatureB"))
        #expect(!qualifiedNames.contains("FeatureA/Sub1"))
        #expect(!qualifiedNames.contains("FeatureA/Sub2"))
    }

    @Test("maxDepth=2 includes one level of sub-modules but not deeper")
    func maxDepthTwoIncludesOneSubLevel() throws {
        let root = try makeTempDir("DepthTwo", structure: [
            "A/A1/A1a/Deep.swift": "let d = 1",
            "A/A2/File.swift": "let f = 2",
            "B/B1.swift": "let b = 3"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 2)
        let modules = scanner.detectModules(in: root)
        let qualifiedNames = Set(modules.map(\.qualifiedName))
        #expect(qualifiedNames.contains("A"))
        #expect(qualifiedNames.contains("A/A1"))
        #expect(qualifiedNames.contains("A/A2"))
        #expect(qualifiedNames.contains("B"))
        // A/A1/A1a should NOT appear at maxDepth=2
        #expect(!qualifiedNames.contains("A/A1/A1a"))
    }

    @Test("Depth field is set correctly")
    func depthFieldIsCorrect() throws {
        let root = try makeTempDir("DepthField", structure: [
            "FeatureA/Sub1/S1.swift": "let s1 = 1",
            "FeatureB/Core.swift": "let b = 2"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 4)
        let modules = scanner.detectModules(in: root)
        let featureA = modules.first { $0.qualifiedName == "FeatureA" }
        let sub1     = modules.first { $0.qualifiedName == "FeatureA/Sub1" }
        let featureB = modules.first { $0.qualifiedName == "FeatureB" }
        #expect(featureA?.depth == 0)
        #expect(sub1?.depth == 1)
        #expect(featureB?.depth == 0)
    }

    @Test("parentQualifiedName is set correctly for nested modules")
    func parentQualifiedNameIsCorrect() throws {
        let root = try makeTempDir("ParentField", structure: [
            "FeatureA/Sub1/S1.swift": "let s1 = 1",
            "FeatureA/Sub2/S2.swift": "let s2 = 2",
            "FeatureB/Core.swift": "let b = 3"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 4)
        let modules = scanner.detectModules(in: root)
        let sub1 = modules.first { $0.qualifiedName == "FeatureA/Sub1" }
        let sub2 = modules.first { $0.qualifiedName == "FeatureA/Sub2" }
        let featureB = modules.first { $0.qualifiedName == "FeatureB" }
        #expect(sub1?.parentQualifiedName == "FeatureA")
        #expect(sub2?.parentQualifiedName == "FeatureA")
        #expect(featureB?.parentQualifiedName == nil)
    }

    @Test("Exclusive file ownership — parent does not double-count sub-module files")
    func exclusiveFileOwnership() throws {
        let root = try makeTempDir("ExclusiveOwnership", structure: [
            "FeatureA/OwnFile.swift":    "let own = 1",    // belongs to FeatureA only
            "FeatureA/Sub1/S1.swift":    "let s1 = 2",    // belongs to FeatureA/Sub1
            "FeatureA/Sub2/S2.swift":    "let s2 = 3",    // belongs to FeatureA/Sub2
            "FeatureA/Sub2/S2b.swift":   "let s2b = 4",
            "FeatureB/Core.swift":       "let b = 5"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 4)
        let modules = scanner.detectModules(in: root)
        let featureA = modules.first { $0.qualifiedName == "FeatureA" }
        let sub1     = modules.first { $0.qualifiedName == "FeatureA/Sub1" }
        let sub2     = modules.first { $0.qualifiedName == "FeatureA/Sub2" }

        // FeatureA should only own OwnFile.swift, not Sub1/Sub2 files
        #expect(featureA?.sourceFiles.count == 1)
        #expect(sub1?.sourceFiles.count == 1)
        #expect(sub2?.sourceFiles.count == 2)
    }

    @Test("Results are sorted alphabetically by module name within each depth level")
    func resultsAreSortedWithinDepth() throws {
        let root = try makeTempDir("SortOrder", structure: [
            "Zebra/Z.swift": "let z = 1",
            "Alpha/A.swift": "let a = 2",
            "Mango/M.swift": "let m = 3"
        ])
        let scanner = ModuleScanner(fileScanner: fileScanner, maxDepth: 1)
        let modules = scanner.detectModules(in: root)
        let names = modules.map(\.name)
        #expect(names == ["Alpha", "Mango", "Zebra"])
    }

    @Test("analyzeModules returns one module for a flat project")
    func analyzeModulesFlat() throws {
        let root = try makeTempDir("FlatAnalyze", structure: [
            "App.swift": "var x = 0",
            "Model.swift": "struct M { }"
        ])
        let analyzer = Analyzer()
        let modules = analyzer.analyzeModules(in: root, fileScanner: fileScanner)
        #expect(modules.count == 1)
    }

    @Test("analyzeModules returns one module per subdirectory for modular project")
    func analyzeModulesModular() throws {
        let root = try makeTempDir("ModularAnalyze", structure: [
            "Core/C.swift": "struct C { }",
            "UI/V.swift": "struct V { }"
        ])
        let analyzer = Analyzer()
        let modules = analyzer.analyzeModules(in: root, fileScanner: fileScanner)
        let names = modules.map(\.name).sorted()
        #expect(names == ["Core", "UI"])
    }

    @Test("Module with findings has status Pending Migration")
    func moduleWithFindingsIsPending() throws {
        let root = try makeTempDir("PendingStatus", structure: [
            "Feature/ViewModel.swift": "var globalState = 0"
        ])
        let analyzer = Analyzer()
        let modules = analyzer.analyzeModules(in: root, fileScanner: fileScanner)
        #expect(modules.first?.status == .pendingMigration)
    }

    @Test("Module with no findings has status Migrated")
    func moduleWithNoFindingsIsMigrated() throws {
        let root = try makeTempDir("MigratedStatus", structure: [
            "Feature/Clean.swift": "let x = 1"
        ])
        let analyzer = Analyzer()
        let modules = analyzer.analyzeModules(in: root, fileScanner: fileScanner)
        #expect(modules.first?.status == .migrated)
    }

    @Test("analyzeAsModule sets correct file count")
    func analyzeAsModuleFileCount() throws {
        let root = try makeTempDir("SingleFileModule", structure: [
            "Single.swift": "let x = 1"
        ])
        let fileURL = root.appendingPathComponent("Single.swift")
        let analyzer = Analyzer()
        let module = analyzer.analyzeAsModule(file: fileURL)
        #expect(module.fileCount == 1)
        #expect(module.depth == 0)
        #expect(module.parentQualifiedName == nil)
    }

    @Test("analyzeAsModule counts non-empty lines of code")
    func analyzeAsModuleLineCount() throws {
        let root = try makeTempDir("LineCount", structure: [
            "Code.swift": "let a = 1\nlet b = 2\n\nlet c = 3\n"
        ])
        let fileURL = root.appendingPathComponent("Code.swift")
        let analyzer = Analyzer()
        let module = analyzer.analyzeAsModule(file: fileURL)
        #expect(module.totalLinesOfCode == 3)
    }

    // MARK: - Helpers

    private func makeTempDir(_ name: String, structure: [String: String]) throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ModuleScannerTmp_\(name)_\(UUID().uuidString.prefix(8))")
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
