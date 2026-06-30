# Changelog

All notable changes to **Swift 6 Migration Analyzer** are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.3.0] — 2026-06-30

### Added

#### New CLI flags
- `--quiet` — suppresses all informational stderr output (module summaries, timing). Fatal errors are still printed. Useful for CI pipelines where only the exit code matters.

#### New suppression directive
- `// swift6-analyzer: disable-file` — place on the **first line** of any source file to suppress all findings in that file. Simpler than annotating every line in a legacy adapter or generated file.

#### `Finding.fix` field
- `Finding` now carries an optional `fix: String?` field for structured fix suggestions.
- When present, `MarkdownReporter` renders it as a `💡 **Fix:**` blockquote below each finding, and `XcodeReporter` appends it to the output line.
- The field is `nil` by default; existing JSON baselines without the field decode cleanly (backward-compatible).

### Changed

#### Architecture — `Analyzer.analyzeModules` is now `async`
- Replaced `DispatchQueue.concurrentPerform` + `NSLock` with `withTaskGroup` (Swift Concurrency).
- Eliminates the contradiction of the tool detecting DispatchQueue/lock usage while using them internally.
- The CLI was updated to `AsyncParsableCommand` to support the new signature.

#### `ToolVersion` — single source of truth for the version string
- New `ToolVersion.current` constant in `Swift6MigrationAnalyzerCore`.
- Referenced by `CLI.swift` and `SARIFReporter`; no more independent hard-coded strings.

#### `FileScanner` — exact exclusion matching
- Directory exclusions now use `==` (exact name match) instead of `contains` (substring match).
- Prevents false exclusions: a directory named `"mybuildpath"` is no longer excluded when `"build"` is in the exclusion list.

#### `FindingComplexity.score(for:)` visibility
- Changed from `public` to `internal`. Use `errorScore(for:)` for all production scoring.
- Tests continue to access it via `@testable import`.

#### `MigrationIndicatorCollector` — simplified merge
- Removed the fragile `merge(_:_:)` static method.
- `collectIndicatorsParsedStatic` now uses `reduce` with the `MigrationIndicators.+` operator, so adding new indicators in future only requires updating `MigrationIndicators.+`.

### Fixed

- `MarkdownReporter`: duplicate "Modules Migrated" row removed from the project overview table.
- `.gitignore`: duplicate `report.html` entry removed.
- `Analyzer.analyzeAsModule`: error messages now go to stderr (was stdout via `print()`).
- `Analyzer.analyzeParsed`: renamed from `analyzeparsed` (camelCase fix).
- `SARIFReporter`: corrected `informationUri` and `helpUri` to `https://github.com/Maetschl/Swift6-migration` (were pointing to a non-existent URL).

### Tests

- Test suite: **424 tests in 38 suites** (was 420 in 38)
- New tests: `disable-file` suppression (4), `Finding.fix` field (5), `XcodeReporter` fix rendering (2), `MarkdownReporter` fix rendering (2)

---

## [1.2.0] — 2026-05-22

### Added

#### New CLI flags
- `--version` — prints the tool version and exits
- `--include-tests` — opt-in analysis of `Tests` and `SnapshotTests` directories (excluded by default)
- `--report` is now **repeatable** — pass it multiple times to generate multiple formats in one run (requires `--output <stem>`)
- `--config <file>` — load settings from a `.swift6-analyzer.json` config file (auto-detected at project root)
- `--baseline <file>` — load a previous JSON report for diff comparison
- `--save-baseline <file>` — persist the current run as a baseline JSON

#### Config file support (`.swift6-analyzer.json`)
Persistent project-level configuration. Supported fields:
```json
{
  "exclude": ["Mocks", "Generated"],
  "maxDepth": 3,
  "includeTests": false,
  "disabledRules": ["ObservableObjectRule"],
  "severityOverrides": { "CompletionHandlerRule": "info" },
  "report": ["html", "json"],
  "baseline": "baseline.json",
  "saveBaseline": "baseline.json"
}
```
CLI flags always override config values.

#### 3 new Swift 6 concurrency rules (18 → 21 total)

| Rule | Severity | Weight | Detects |
|------|----------|--------|---------|
| `ActorReentrancyRule` | ⚠️ warning | 0.7 | `async` actor methods awaiting external calls — reentrancy window while suspended |
| `WithUnsafeCurrentTaskRule` | ⚠️ warning | 0.4 | Deprecated `Task.current` and `withUnsafeCurrentTask { }` APIs |
| `AsyncSequenceRule` | ⚠️ warning | 0.5 | `PassthroughSubject` / `CurrentValueSubject` — candidates for `AsyncStream` migration |

#### New report formats
- **`--report xcode`** — `XcodeReporter`: outputs `file:line:col: warning/error: [Rule] message` for use as an Xcode build phase script
- **`--report diff`** — `DiffReporter`: Markdown diff report showing new findings, resolved findings, and per-module score deltas (requires `--baseline`)

#### Baseline / diff infrastructure
- New `BaselineComparator` — compares two `[ModuleResult]` sets and produces a `BaselineDiff` (new findings, resolved findings, score deltas, new/removed modules)
- New `DiffReporter` — renders a `BaselineDiff` as human-readable Markdown

#### Analyzer improvements
- `Analyzer.init` now accepts `disabledRules: [String]` and `severityOverrides: [String: String]`
- `ModuleScanner.init` now accepts `includeTests: Bool`
- **Parallel module analysis** — `analyzeModules` now runs each module concurrently via `DispatchQueue.concurrentPerform`, cutting wall-clock time proportionally to module count

### Changed
- SARIF `tool.driver.version` bumped from `1.0.0` to `1.2.0`
- `Tests` and `SnapshotTests` exclusion moved from `FileScanner` to `ModuleScanner` (more precise — `FileScanner` no longer blanket-excludes directories whose name contains "Tests")

### Fixed
- `FileScanner` previously excluded any directory whose path component _contained_ the string "Tests" (e.g. `AuthenticationTests`). The exclusion is now applied by `ModuleScanner` using exact suffix matching, so only directories named `Tests`, `SnapshotTests`, or ending in `Test`/`Tests` are excluded.

### Tests
- Test suite: **420 tests in 38 suites** (was 253 in 24)
- New test files: `ActorReentrancyRuleTests`, `WithUnsafeCurrentTaskRuleTests`, `AsyncSequenceRuleTests`, `XcodeReporterTests`, `DiffReporterTests`, `BaselineComparatorTests`

---

## [1.1.x] — prior releases

_No changelog was maintained before v1.2.0. See git history for changes._
