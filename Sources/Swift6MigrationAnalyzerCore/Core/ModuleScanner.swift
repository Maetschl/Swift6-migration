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
    /// When true, directories that look like test targets are not excluded.
    public let includeTests: Bool

    public init(fileScanner: FileScanner, maxDepth: Int = 4, includeTests: Bool = false) {
        self.fileScanner = fileScanner
        self.maxDepth = max(1, maxDepth)
        self.includeTests = includeTests
    }

    // MARK: - Public API

    /// Detects all modules recursively and returns them in depth-first tree order
    /// (parent before its children; siblings sorted alphabetically).
    ///
    /// - Parameter onProgress: Optional callback invoked at key detection milestones.
    ///   Receives a human-readable status string for progress display.
    public func detectModules(
        in directory: URL,
        onProgress: ((String) -> Void)? = nil
    ) -> [ModuleInfo] {
        // Pre-scan all Swift files once — avoids O(n²) repeated filesystem walks.
        onProgress?("📂 Scanning Swift files… (this may take a moment for large projects)")
        var lastReported = 0
        let allSwiftFiles = fileScanner.scan(directory: directory) { currentDir, found in
            // Print every 100 files to stay readable without flooding output
            if found - lastReported >= 100 || lastReported == 0 {
                lastReported = found
                onProgress?("📂 \(found) Swift files found so far…  [→ \(currentDir)]")
            }
        }
        onProgress?("📂 Done — \(allSwiftFiles.count) Swift file(s) found. Building module tree…")
        let fileCache = FileCache(files: allSwiftFiles)
        let result = detectRecursive(
            in: directory, depth: 0, parentQualifiedName: nil,
            cache: fileCache, onProgress: onProgress
        )
        onProgress?("✅ Module detection complete — \(result.count) module(s) found")
        return result
    }

    // MARK: - Recursive core

    private func detectRecursive(
        in directory: URL,
        depth: Int,
        parentQualifiedName: String?,
        cache: FileCache,
        onProgress: ((String) -> Void)? = nil
    ) -> [ModuleInfo] {
        let fm = FileManager.default
        let subdirs = immediateSubdirectories(of: directory, using: fm)

        if let p = onProgress {
            let indent = String(repeating: "  ", count: depth)
            p("\(indent)🔍 Inspecting \(directory.lastPathComponent) (\(subdirs.count) subdir(s))")
        }

        let topLevelInfos = detectTopLevel(
            in: directory, subdirs: subdirs, fm: fm,
            depth: depth, parentQualifiedName: parentQualifiedName, cache: cache
        )

        // If nothing detected at this level and we are at depth 0, fall back to single module
        if topLevelInfos.isEmpty && depth == 0 {
            return [ModuleInfo(
                name: directory.lastPathComponent,
                qualifiedName: directory.lastPathComponent,
                rootURL: directory,
                sourceFiles: cache.files(under: directory),
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
                parentQualifiedName: info.qualifiedName,
                cache: cache,
                onProgress: onProgress
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
        parentQualifiedName: String?,
        cache: FileCache
    ) -> [ModuleInfo] {

        // Strategy 1 — Multi-package workspace: immediate subdirs each have Package.swift
        let packageSubdirs = subdirs.filter {
            fm.fileExists(atPath: $0.appendingPathComponent("Package.swift").path)
        }
        if !packageSubdirs.isEmpty {
            return packageSubdirs
                .compactMap { build(dir: $0, depth: depth, parentQualifiedName: parentQualifiedName, fm: fm, cache: cache) }
        }

        // Strategy 2 — SPM package with Package.swift: use Sources/ filesystem heuristic.
        // (Previously used `swift package dump-package` but that spawns a subprocess per package —
        //  far too slow for large monorepos with many Package.swift files.)
        let rootHasManifest = fm.fileExists(
            atPath: directory.appendingPathComponent("Package.swift").path
        )
        if rootHasManifest {
            let sourcesDir = directory.appendingPathComponent("Sources")
            if fm.fileExists(atPath: sourcesDir.path) {
                let targetDirs = immediateSubdirectories(of: sourcesDir, using: fm)
                    .filter { !isTestDirectory($0) }
                if targetDirs.count > 1 {
                    let modules = targetDirs
                        .compactMap { build(dir: $0, depth: depth, parentQualifiedName: parentQualifiedName, fm: fm, cache: cache) }
                    if !modules.isEmpty { return modules }
                }
            }
        }

        // Strategy 3 — Modular directory layout
        let subdirModules = subdirs
            .compactMap { build(dir: $0, depth: depth, parentQualifiedName: parentQualifiedName, fm: fm, cache: cache) }
        // At depth>0 even a single subdir should propagate (we already committed to recursing)
        if subdirModules.count > 1 || (depth > 0 && !subdirModules.isEmpty) {
            return subdirModules
        }

        // Strategy 4 — no split at this level
        return []
    }

    // MARK: - Module builder (exclusive ownership)

    private func build(dir: URL, overrideName: String? = nil, depth: Int, parentQualifiedName: String?, fm: FileManager, cache: FileCache) -> ModuleInfo? {
        let subdirs = immediateSubdirectories(of: dir, using: fm)
        let subRoots = subModuleRootURLs(in: dir, subdirs: subdirs, fm: fm, cache: cache)
        let exclusiveFiles = exclusiveSourceFiles(in: dir, excludingRoots: subRoots, cache: cache)

        let isPackageBoundary = fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path)
        let hasSourcesDir     = fm.fileExists(atPath: dir.appendingPathComponent("Sources").path)

        guard !exclusiveFiles.isEmpty || isPackageBoundary || hasSourcesDir || cache.hasFiles(under: dir) else { return nil }

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
    /// Used purely for file-ownership boundary detection — must stay filesystem-based.
    /// PackageManifestParser is only used in detectTopLevel for module *discovery*, not here.
    private func subModuleRootURLs(in directory: URL, subdirs: [URL], fm: FileManager, cache: FileCache) -> Set<URL> {
        let pkgSubdirs = subdirs.filter {
            fm.fileExists(atPath: $0.appendingPathComponent("Package.swift").path)
        }
        if !pkgSubdirs.isEmpty { return Set(pkgSubdirs) }

        // Filesystem Sources/ subdirs — no manifest call (too slow + wrong paths on real projects)
        let sourcesDir = directory.appendingPathComponent("Sources")
        if fm.fileExists(atPath: directory.appendingPathComponent("Package.swift").path),
           fm.fileExists(atPath: sourcesDir.path) {
            let targetDirs = immediateSubdirectories(of: sourcesDir, using: fm)
                .filter { !isTestDirectory($0) }
            if targetDirs.count > 1 { return Set(targetDirs) }
        }

        let swiftSubdirs = subdirs.filter { cache.hasFiles(under: $0) }
        if swiftSubdirs.count > 1 { return Set(swiftSubdirs) }

        return []
    }

    private func exclusiveSourceFiles(in directory: URL, excludingRoots excluded: Set<URL>, cache: FileCache) -> [URL] {
        let all = cache.files(under: directory)
        guard !excluded.isEmpty else { return all }
        // Resolve symlinks on excluded roots so paths match the resolved paths stored in FileCache.
        let resolvedRoots = excluded.map { $0.resolvingSymlinksInPath().path }
        return all.filter { file in
            !resolvedRoots.contains { resolvedRoot in
                file.path.hasPrefix(resolvedRoot + "/") || file.path == resolvedRoot
            }
        }
    }

    private static let excludedDirNames: Set<String> = [
        ".build", "build", "Pods", "Carthage", "DerivedData",
        ".git", "xcuserdata", ".swiftpm", "checkouts"
    ]

    private func immediateSubdirectories(of directory: URL, using fm: FileManager) -> [URL] {
        let contents = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.filter {
            guard (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
            return !Self.excludedDirNames.contains($0.lastPathComponent)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Returns true if a directory name looks like a test target.
    private func isTestDirectory(_ url: URL) -> Bool {
        guard !includeTests else { return false }
        let name = url.lastPathComponent
        return name.hasSuffix("Tests") || name.hasSuffix("Test") ||
               name.hasSuffix("SnapshotTests") || name == "Tests"
    }
}

// MARK: - FileCache

/// Holds a pre-scanned list of all Swift files and provides O(1)-ish prefix lookups,
/// eliminating repeated recursive filesystem scans during module detection.
private struct FileCache {
    private let sortedPaths: [String]

    init(files: [URL]) {
        // Resolve symlinks so that paths from FileManager.enumerator (which resolves symlinks
        // on macOS, e.g. /var/folders → /private/var/folders) are consistent with the
        // directory URLs used for prefix matching.
        self.sortedPaths = files.map { $0.resolvingSymlinksInPath().path }.sorted()
    }

    private func resolvedPrefix(for directory: URL) -> String {
        return directory.resolvingSymlinksInPath().path + "/"
    }

    /// All files whose path starts with `directory.path + "/"`.
    func files(under directory: URL) -> [URL] {
        let prefix = resolvedPrefix(for: directory)
        return sortedPaths
            .filter { $0.hasPrefix(prefix) }
            .map { URL(fileURLWithPath: $0) }
    }

    /// Whether any file exists under `directory`.
    func hasFiles(under directory: URL) -> Bool {
        let prefix = resolvedPrefix(for: directory)
        return sortedPaths.contains { $0.hasPrefix(prefix) }
    }
}
