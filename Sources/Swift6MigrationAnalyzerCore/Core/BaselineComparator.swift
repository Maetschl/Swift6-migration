public struct BaselineDiff: Sendable {
    /// Findings present in current but not in baseline (regressions)
    public let newFindings: [Finding]
    /// Findings present in baseline but not in current (fixed)
    public let resolvedFindings: [Finding]
    /// Score delta per module name: positive = regression, negative = improvement
    public let scoreDeltas: [String: Double]
    /// Overall score delta (current total - baseline total)
    public let totalScoreDelta: Double
    /// Modules that appear in current but not in baseline
    public let newModules: [String]
    /// Modules that appear in baseline but not in current
    public let removedModules: [String]

    public init(
        newFindings: [Finding] = [],
        resolvedFindings: [Finding] = [],
        scoreDeltas: [String: Double] = [:],
        totalScoreDelta: Double = 0,
        newModules: [String] = [],
        removedModules: [String] = []
    ) {
        self.newFindings = newFindings
        self.resolvedFindings = resolvedFindings
        self.scoreDeltas = scoreDeltas
        self.totalScoreDelta = totalScoreDelta
        self.newModules = newModules
        self.removedModules = removedModules
    }
}

public struct BaselineComparator: Sendable {
    public init() {}

    public func compare(baseline: [ModuleResult], current: [ModuleResult]) -> BaselineDiff {
        let baselineFindings = baseline.flatMap(\.findings)
        let currentFindings = current.flatMap(\.findings)

        let baselineKeys = Set(baselineFindings.map(FindingKey.init))
        let currentKeys = Set(currentFindings.map(FindingKey.init))

        let newFindings = currentFindings
            .filter { !baselineKeys.contains(FindingKey($0)) }
            .sorted(by: Self.sortFindings)

        let resolvedFindings = baselineFindings
            .filter { !currentKeys.contains(FindingKey($0)) }
            .sorted(by: Self.sortFindings)

        let baselineModules = Dictionary(uniqueKeysWithValues: baseline.map { ($0.qualifiedName, $0) })
        let currentModules = Dictionary(uniqueKeysWithValues: current.map { ($0.qualifiedName, $0) })

        let sharedModules = Set(baselineModules.keys).intersection(currentModules.keys)
        let scoreDeltas = sharedModules.reduce(into: [String: Double]()) { partialResult, name in
            guard let baselineModule = baselineModules[name], let currentModule = currentModules[name] else {
                return
            }

            let delta = currentModule.score - baselineModule.score
            if delta != 0 {
                partialResult[name] = delta
            }
        }

        return BaselineDiff(
            newFindings: newFindings,
            resolvedFindings: resolvedFindings,
            scoreDeltas: scoreDeltas,
            totalScoreDelta: current.reduce(0) { $0 + $1.score } - baseline.reduce(0) { $0 + $1.score },
            newModules: Set(currentModules.keys).subtracting(baselineModules.keys).sorted(),
            removedModules: Set(baselineModules.keys).subtracting(currentModules.keys).sorted()
        )
    }

    private struct FindingKey: Hashable {
        let file: String
        let line: Int
        let column: Int
        let rule: String

        init(_ finding: Finding) {
            self.file = finding.file
            self.line = finding.line
            self.column = finding.column
            self.rule = finding.rule
        }
    }

    private static func sortFindings(_ lhs: Finding, _ rhs: Finding) -> Bool {
        if lhs.file != rhs.file { return lhs.file < rhs.file }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        if lhs.column != rhs.column { return lhs.column < rhs.column }
        return lhs.rule < rhs.rule
    }
}
