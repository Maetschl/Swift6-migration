public protocol Reporter: Sendable {
    func generate(findings: [Finding]) -> String
    func generate(modules: [ModuleResult], projectName: String) -> String
}

public extension Reporter {
    /// Default implementation: flatten all modules into a single findings list.
    func generate(modules: [ModuleResult], projectName: String) -> String {
        generate(findings: modules.flatMap { $0.findings })
    }
}
