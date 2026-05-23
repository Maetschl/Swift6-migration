# Changelog

All notable changes to **Swift 6 Migration Analyzer** are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
