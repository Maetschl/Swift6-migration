import Foundation

public struct FileScanner: Sendable {
    private static let defaultExclusions = [
        "Pods", "Carthage", "DerivedData", "build",
        ".build", ".git"
    ]

    private let exclusions: [String]

    public init(additionalExclusions: [String] = []) {
        self.exclusions = Self.defaultExclusions + additionalExclusions
    }

    /// Scans `directory` recursively and returns all `.swift` files.
    ///
    /// - Parameter onProgress: Called periodically during scanning with the current
    ///   directory being visited and total Swift files found so far. Fires once per
    ///   directory entered (not per file) to keep output readable.
    public func scan(
        directory: URL,
        onProgress: ((_ currentDir: String, _ swiftFilesFound: Int) -> Void)? = nil
    ) -> [URL] {
        var results: [URL] = []
        let fm = FileManager.default
        var lastReportedDir = ""

        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let url as URL in enumerator {
            let pathComponents = url.pathComponents
            if pathComponents.contains(where: { component in
                exclusions.contains { $0 == component }
            }) {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Report progress whenever we enter a new directory
            if let progress = onProgress {
                let dir = url.deletingLastPathComponent().lastPathComponent
                if dir != lastReportedDir {
                    lastReportedDir = dir
                    progress(dir, results.count)
                }
            }

            guard url.pathExtension == "swift" else { continue }
            results.append(url)
        }

        return results.sorted { $0.path < $1.path }
    }
}
