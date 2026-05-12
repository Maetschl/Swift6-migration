import Foundation

/// A lightweight parser that extracts target information from a Swift Package manifest
/// by invoking `swift package dump-package`, which returns authoritative JSON.
///
/// This is the single source of truth for which targets exist, their type, and their
/// source path — replacing filesystem-based heuristics in `ModuleScanner`.
public struct PackageManifestParser: Sendable {

    // MARK: - Public types

    public enum TargetType: String, Sendable {
        case regular
        case executable
        case test
        case plugin
        case macro
        case binary
        case unknown
    }

    public struct TargetInfo: Sendable {
        /// The target name as declared in Package.swift.
        public let name: String
        /// The target type.
        public let type: TargetType
        /// The resolved absolute path to the target's source directory.
        public let sourcePath: URL
    }

    // MARK: - Public API

    /// Parses the `Package.swift` at `packageDirectory` and returns all declared targets.
    ///
    /// - Parameter packageDirectory: Directory containing `Package.swift`.
    /// - Returns: Array of `TargetInfo`, or `nil` if parsing fails (e.g. no Swift toolchain).
    public static func targets(in packageDirectory: URL) -> [TargetInfo]? {
        guard let json = dumpPackageJSON(at: packageDirectory) else { return nil }
        return parse(json: json, packageDirectory: packageDirectory)
    }

    /// Returns only source targets (`.regular` and `.executable`), excluding test/plugin/macro targets.
    public static func sourceTargets(in packageDirectory: URL) -> [TargetInfo]? {
        targets(in: packageDirectory)?.filter { $0.type == .regular || $0.type == .executable }
    }

    // MARK: - Private: invoke swift package dump-package

    private static func dumpPackageJSON(at directory: URL) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "package", "--package-path", directory.path, "dump-package"]
        process.environment = ProcessInfo.processInfo.environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // silence stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return data.isEmpty ? nil : data
    }

    // MARK: - JSON parsing (internal so tests can call it directly with fixture data)

    /// Parses `dump-package` JSON into `TargetInfo` array.
    /// Exposed as `internal` so tests can inject fixture JSON without spawning a subprocess.
    static func parse(json: Data, packageDirectory: URL) -> [TargetInfo]? {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let targets = root["targets"] as? [[String: Any]] else { return nil }

        return targets.compactMap { target -> TargetInfo? in
            guard let name = target["name"] as? String else { return nil }

            let typeStr = target["type"] as? String ?? "regular"
            let type_   = TargetType(rawValue: typeStr) ?? .unknown

            // Resolve source path: use explicit "path" if declared, else default Sources/<name>
            let sourcePath: URL
            if let explicitPath = target["path"] as? String {
                // Explicit path is relative to the package directory
                sourcePath = packageDirectory.appendingPathComponent(explicitPath)
            } else {
                sourcePath = packageDirectory
                    .appendingPathComponent("Sources")
                    .appendingPathComponent(name)
            }

            return TargetInfo(name: name, type: type_, sourcePath: sourcePath)
        }
    }
}
