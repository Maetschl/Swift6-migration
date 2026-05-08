import Foundation

/// A lightweight descriptor for a detected module before analysis.
public struct ModuleInfo: Sendable {
    public let name: String
    public let rootURL: URL
    public let sourceFiles: [URL]
}

/// Detects modules (packages, SPM targets, or top-level directories) inside a project root.
///
/// Detection priority:
/// 1. **Multi-package workspace** — immediate subdirectories each containing `Package.swift`.
/// 2. **Single SPM package with multiple targets** — root has `Package.swift` and `Sources/`
///    contains multiple subdirectories (each target is treated as a module).
/// 3. **Modular directory layout** — immediate subdirectories that contain `.swift` files.
/// 4. **Single non-modular project** — everything under the root is one module.
public struct ModuleScanner: Sendable {
    private let fileScanner: FileScanner

    public init(fileScanner: FileScanner) {
        self.fileScanner = fileScanner
    }

    public func detectModules(in directory: URL) -> [ModuleInfo] {
        let fm = FileManager.default
        let subdirectories = immediateSubdirectories(of: directory, using: fm)

        // Strategy 1 — Multi-package workspace (each subdir has its own Package.swift)
        let packageSubdirs = subdirectories.filter {
            fm.fileExists(atPath: $0.appendingPathComponent("Package.swift").path)
        }
        if !packageSubdirs.isEmpty {
            return packageSubdirs
                .map { build(name: $0.lastPathComponent, root: $0) }
                .filter { !$0.sourceFiles.isEmpty }
        }

        // Strategy 2 — Single SPM package with multiple targets under Sources/
        let rootHasPackageManifest = fm.fileExists(
            atPath: directory.appendingPathComponent("Package.swift").path
        )
        let sourcesDirectory = directory.appendingPathComponent("Sources")
        let sourcesExists = fm.fileExists(atPath: sourcesDirectory.path)

        if rootHasPackageManifest && sourcesExists {
            let targetDirectories = immediateSubdirectories(of: sourcesDirectory, using: fm)
            if targetDirectories.count > 1 {
                let modules = targetDirectories
                    .map { build(name: $0.lastPathComponent, root: $0) }
                    .filter { !$0.sourceFiles.isEmpty }
                if !modules.isEmpty { return modules }
            }
        }

        // Strategy 3 — Modular directory layout (subdirs with Swift files = modules)
        let subdirModules = subdirectories
            .map { build(name: $0.lastPathComponent, root: $0) }
            .filter { !$0.sourceFiles.isEmpty }

        if subdirModules.count > 1 {
            return subdirModules
        }

        // Strategy 4 — Single non-modular project
        let allFiles = fileScanner.scan(directory: directory)
        return [ModuleInfo(name: directory.lastPathComponent, rootURL: directory, sourceFiles: allFiles)]
    }

    // MARK: - Helpers

    private func build(name: String, root: URL) -> ModuleInfo {
        ModuleInfo(name: name, rootURL: root, sourceFiles: fileScanner.scan(directory: root))
    }

    private func immediateSubdirectories(of directory: URL, using fm: FileManager) -> [URL] {
        let contents = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
