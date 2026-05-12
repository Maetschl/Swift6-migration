import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

// All tests inject pre-built JSON so no `swift package dump-package` subprocess
// is ever spawned (spawning `swift` inside `swift test` deadlocks on the SPM build lock).

private func makeJSON(targets: [[String: Any]]) -> Data {
    let root: [String: Any] = ["targets": targets]
    return try! JSONSerialization.data(withJSONObject: root)
}

private let packageDir = URL(fileURLWithPath: "/tmp/FakePkg")

@Suite("PackageManifestParser")
struct PackageManifestParserTests {

    @Test("Parses regular target correctly")
    func parsesRegularTarget() {
        let json = makeJSON(targets: [["name": "CoreModule", "type": "regular"]])
        let targets = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(targets?.count == 1)
        #expect(targets?.first?.name == "CoreModule")
        #expect(targets?.first?.type == .regular)
    }

    @Test("Parses executable target correctly")
    func parsesExecutableTarget() {
        let json = makeJSON(targets: [["name": "AppRunner", "type": "executable"]])
        let targets = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(targets?.first?.type == .executable)
    }

    @Test("Parses test target correctly")
    func parsesTestTarget() {
        let json = makeJSON(targets: [["name": "CoreModuleTests", "type": "test"]])
        let targets = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(targets?.first?.type == .test)
    }

    @Test("Parses plugin target correctly")
    func parsesPluginTarget() {
        let json = makeJSON(targets: [["name": "MyPlugin", "type": "plugin"]])
        let targets = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(targets?.first?.type == .plugin)
    }

    @Test("Unknown type string maps to .unknown")
    func unknownTypeMapsToUnknown() {
        let json = makeJSON(targets: [["name": "Weird", "type": "someFutureType"]])
        let targets = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(targets?.first?.type == .unknown)
    }

    @Test("Missing type defaults to regular")
    func missingTypeDefaultsToRegular() {
        let json = makeJSON(targets: [["name": "NoType"]])
        let targets = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(targets?.first?.type == .regular)
    }

    @Test("Default path resolves to Sources/<name>")
    func defaultPathResolvesToSourcesName() {
        let json = makeJSON(targets: [["name": "CoreModule", "type": "regular"]])
        let targets = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        let expected = packageDir.appendingPathComponent("Sources/CoreModule").path
        #expect(targets?.first?.sourcePath.path == expected)
    }

    @Test("Explicit path override is resolved relative to package directory")
    func explicitPathIsResolved() {
        let json = makeJSON(targets: [["name": "Lib", "type": "regular", "path": "Lib/Core"]])
        let targets = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        let expected = packageDir.appendingPathComponent("Lib/Core").path
        #expect(targets?.first?.sourcePath.path == expected)
    }

    @Test("Parses multiple targets in one manifest")
    func parsesMultipleTargets() {
        let json = makeJSON(targets: [
            ["name": "Auth",      "type": "regular"],
            ["name": "Dashboard", "type": "regular"],
            ["name": "Settings",  "type": "regular"],
            ["name": "AuthTests", "type": "test"]
        ])
        let all = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(all?.count == 4)
    }

    @Test("sourceTargets logic filters out test and plugin targets")
    func sourceTargetsFiltersTests() {
        let json = makeJSON(targets: [
            ["name": "Auth",      "type": "regular"],
            ["name": "AuthTests", "type": "test"],
            ["name": "CLI",       "type": "executable"],
            ["name": "MyPlugin",  "type": "plugin"]
        ])
        let all = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        let source = all?.filter { $0.type == .regular || $0.type == .executable }
        #expect(source?.count == 2)
        #expect(source?.contains { $0.name == "Auth" } == true)
        #expect(source?.contains { $0.name == "CLI" } == true)
        #expect(source?.contains { $0.name == "AuthTests" } == false)
    }

    @Test("sourceTargets excludes macro and binary targets")
    func sourceTargetsExcludesMacroAndBinary() {
        let json = makeJSON(targets: [
            ["name": "Core",    "type": "regular"],
            ["name": "MyMacro","type": "macro"],
            ["name": "Prebuilt","type": "binary"]
        ])
        let all = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        let source = all?.filter { $0.type == .regular || $0.type == .executable }
        #expect(source?.count == 1)
        #expect(source?.first?.name == "Core")
    }

    @Test("Returns nil for empty JSON data")
    func returnsNilForEmptyData() {
        let result = PackageManifestParser.parse(json: Data(), packageDirectory: packageDir)
        #expect(result == nil)
    }

    @Test("Returns nil for JSON with no targets key")
    func returnsNilForMissingTargetsKey() {
        let json = try! JSONSerialization.data(withJSONObject: ["name": "MyPkg"])
        let result = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(result == nil)
    }

    @Test("Skips target entries missing a name field")
    func skipsMissingNameField() {
        let json = makeJSON(targets: [
            ["type": "regular"],
            ["name": "Valid", "type": "regular"]
        ])
        let result = PackageManifestParser.parse(json: json, packageDirectory: packageDir)
        #expect(result?.count == 1)
        #expect(result?.first?.name == "Valid")
    }
}
