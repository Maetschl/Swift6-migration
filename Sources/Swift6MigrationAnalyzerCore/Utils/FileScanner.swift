import Foundation

public struct FileScanner: Sendable {
    private static let defaultExclusions = [
        "Pods", "Carthage", "DerivedData", "build",
        ".build", ".git", "Tests", "SnapshotTests"
    ]

    private let exclusions: [String]

    public init(additionalExclusions: [String] = []) {
        self.exclusions = Self.defaultExclusions + additionalExclusions
    }

    public func scan(directory: URL) -> [URL] {
        var results: [URL] = []
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let url as URL in enumerator {
            let pathComponents = url.pathComponents
            if pathComponents.contains(where: { component in
                exclusions.contains(where: { excl in
                    component == excl || component.contains(excl)
                })
            }) {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard url.pathExtension == "swift" else { continue }
            results.append(url)
        }

        return results.sorted { $0.path < $1.path }
    }
}
