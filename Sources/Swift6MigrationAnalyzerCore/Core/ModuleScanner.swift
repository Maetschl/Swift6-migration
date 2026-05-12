import Foundation

/// A lightweight descriptor for a detected module before analysis.
public struct ModuleInfo: Sendable {
    public let name: String
    /// Qualified name including parent path, e.g. "FeatureA/Networking/Core".
    public let qualifiedName: String
    public let rootURL: URL
    /// Swift files that belong **exclusively** to this module (not inside any detected sub-module).
    public let sourceFiles: [URL]
    /// Nesting depth (0 = top-level).
    public let depth: Int
    /// Qualified name of the parent, nil for top-level modules.
    public let parentQualifiedName: String?
}

/// Detects modules (packages, SPM targets, or directories) inside a project root,
/// recursively up to `maxDepth` levels.
///
/// ### Detection strategies (applied at each level)
/// 1. **Multi-package workspace** — immediate subdirectories each containing `Package.swift`.
/// 2. **Single SPM package with multiple targets** — root has `Package.swift` and `Sources/`
///    contains multiple subdirectories.
/// 3. **Modular directory layout** — immediate subdirectories that contain `.swift` files.
/// 4. **Single non-modular project** — everything under the root is one module (only at depth 0).
///
/// ### File ownership
/// Each Swift file belongs to the **deepest** detected module. A parent module only holds
/// files that sit directly in its own directory (not inside any sub-module subdirectory).
public struct ModuleScanner: Sendable {
    private let fileScanner: FileScanner
    /// Maximum recursion depth. Default is 4.
    public let maxDepth: Int

    public init(fileScanner: FileScanner, maxDepth: Int = 4) {
        self.fileScanner = fileScanner
        self.maxDepth = max(1, maxDepth)
    }

    // MARK: - Public API

    /// Detects all modules recursively and returns them in depth-first tree order
    /// (parent before its children; siblings sorted alphabetically).
    public func detectModules(in directory: URL) -> [ModuleInfo] {
        detectRecursive(in: directory, depth: 0, parentQualifiedName: nil)
    }

    // MARK: - Recursive core

    private func detectRecursive(
        in directory: URL,
        depth: Int,
        parentQualifiedName: String?
    ) -> [ModuleInfo] {
        let fm = FileManager.default
        let subdirs = immediateSubdirectories(of: directory, using: fm)

        let topLevelInfos = detectTopLevel(
            in: directory, subdirs: subdirs, fm: fm,
            depth: depth, parentQualifiedName: parentQualifiedName
        )

        // If nothing detected at this level and we are at depth 0, fall back to single module
        if topLevelInfos.isEmpty && depth == 0 {
            let allFiles = fileScanner.scan(directory: directory)
            return [ModuleInfo(
                name: directory.lastPathComponent,
                qualifiedName: directory.lastPathComponent,
                rootURL: directory,
                sourceFiles: allFiles,
                depth: 0,
                parentQualifiedName: nil
            )]
        }

        guard !topLevelInfos.isEmpty else { return [] }

        var result: [ModuleInfo] = []
        for info in topLevelInfos {
            result.append(info)                          // parent before children

            guard depth + 1 < maxDepth else { continue } // depth limit

            let children = detectRecursive(
                in: info.rootURL,
                depth: depth + 1,
                parentQualifiedName: info.qualifiedName
            )
            result.append(contentsOf: children)
        }
        return result
    }

    // MARK: - Single-level detection

    private func detectTopLevel(
        in directory: URL,
        subdirs: [URL],
        fm: FileManager,
        depth: Int,
        parentQualifiedName: String?
    ) -> [ModuleInfo] {

        // Strategy 1 — Multi-package workspace: immediate subdirs each have Package.swift
        let packageSubdirs = subdirs.filter {
            fm.fileExists(atPath: $0.appendingPathComponent("Package.swift").path)
        }
        if !packageSubdirs.isEmpty {
            return packageSubdirs
                .compactMap { build(dir: $0, depth: depth, parentQualifiedName: parentQualifiedName, fm: fm) }
        }

        // Strategy 2 — SPM package guided by Package.swift manifest
        let rootHasManifest = fm.fileExists(
            atPath: directory.appendingPathComponent("Package.swift").path
        )
        if rootHasManifest {
            // Use PackageManifestParser to get authoritative source targets (excludes test/plugin targets)
            if let sourceTargets = PackageManifestParser.sourceTargets(in: directory),
               sourceTargets.count > 1 {
                let modules = sourceTargets
                    .filter { fm.fileExists(atPath: $0.sourcePath.path) }
                    .compactMap { target -> ModuleInfo? in
                        build(dir: target.sourcePath,
                              overrideName: target.name,
                              depth: depth,
                              parentQualifiedName: parentQualifiedName,
                              fm: fm)
                    }
                if !modules.isEmpty { return modules }
            }

            // Fallback: read Sources/ from filesystem if dump-package is unavailable
            let sourcesDir = directory.appendingPathComponent("Sources")
            if fm.fileExists(atPath: sourcesDir.path) {
                let targetDirs = immediateSubdirectories(of: sourcesDir, using: fm)
                    .filter { !isTestDirectory($0) }
                if targetDirs.count > 1 {
                    let modules = targetDirs
                        .compactMap { build(dir: $0, depth: depth, parentQualifiedName: parentQualifiedName, fm: fm) }
                    if !modules.isEmpty { return modules }
                }
            }
        }

        // Strategy 3 — Modular directory layout
        let subdirModules = subdirs
            .compactMap { build(dir: $0, depth: depth, parentQualifiedName: parentQualifiedName, fm: fm) }
        // At depth>0 even a single subdir should propagate (we already committed to recursing)
        if subdirModules.count > 1 || (depth > 0 && !subdirModules.isEmpty) {
            return subdirModules
        }

        // Strategy 4 — no split at this level
        return []
    }

    // MARK: - Module builder (exclusive ownership)

    private func build(dir: URL, overrideName: String? = nil, depth: Int, parentQualifiedName: String?, fm: FileManager) -> ModuleInfo? {
        let subdirs = immediateSubdirectories(of: dir, using: fm)
        let subRoots = subModuleRootURLs(in: dir, subdirs: subdirs, fm: fm)
        let exclusiveFiles = exclusiveSourceFiles(in: dir, excludingRoots: subRoots)

        let isPackageBoundary = fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path)
        let hasSourcesDir     = fm.fileExists(atPath: dir.appendingPathComponent("Sources").path)

        guard !exclusiveFiles.isEmpty || isPackageBoundary || hasSourcesDir || hasSwiftFiles(in: dir) else { return nil }

        let parentPrefix  = parentQualifiedName.map { $0 + "/" } ?? ""
        let moduleName    = overrideName ?? dir.lastPathComponent
        let qualifiedName = parentPrefix + moduleName

        return ModuleInfo(
            name: moduleName,
            qualifiedName: qualifiedName,
            rootURL: dir,
            sourceFiles: exclusiveFiles,
            depth: depth,
            parentQualifiedName: parentQualifiedName
        )
    }

    /// Returns the URLs that would become sub-module roots at the next recursion level.
    private func subModuleRootURLs(in directory: URL, subdirs: [URL], fm: FileManager) -> Set<URL> {
        let pkgSubdirs = subdirs.filter {
            fm.fileExists(atPath: $0.appendingPathComponent("Package.swift").path)
        }
        if !pkgSubdirs.isEmpty { return Set(pkgSubdirs) }

        let sourcesDir = directory.appendingPathComponent("Sources")
        if fm.fileExists(atPath: directory.appendingPathComponent("Package.swift").path),
           fm.fileExists(atPath: sourcesDir.path) {
            let targetDirs = immediateSubdirectories(of: sourcesDir, using: fm)
            if targetDirs.count > 1 { return Set(targetDirs) }
        }

        let swiftSubdirs = subdirs.filter { hasSwiftFiles(in: $0) }
        if swiftSubdirs.count > 1 { return Set(swiftSubdirs) }

        return []
    }

    private func exclusiveSourceFiles(in directory: URL, excludingRoots excluded: Set<URL>) -> [URL] {
        let all = fileScanner.scan(directory: directory)
        guard !excluded.isEmpty else { return all }
        return all.filter { file in
            !excluded.contains { root in
                file.path.hasPrefix(root.path + "/") || file.path == root.path
            }
        }
    }

    private func hasSwiftFiles(in directory: URL) -> Bool {
        !fileScanner.scan(directory: directory).isEmpty
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

    /// Returns true if a directory name looks like a test target (heuristic fallback only —
    /// `PackageManifestParser` is preferred for SPM packages).
    private func isTestDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasSuffix("Tests") || name.hasSuffix("Test") ||
               name.hasSuffix("SnapshotTests") || name == "Tests"
    }
}
