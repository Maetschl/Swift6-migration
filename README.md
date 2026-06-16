# Swift 6 Migration Analyzer

A command-line tool to analyze Swift 5 codebases and detect patterns that need attention when migrating to Swift 6. Built with SwiftSyntax for accurate, syntax-based analysis.

<img width="1162" height="992" alt="Screenshot 2026-05-09 at 01 00 53" src="https://github.com/user-attachments/assets/0ca318e8-6809-4ba7-9b11-73ff7ce4937a" />

---

## Features

- 🔍 Recursively scans Swift projects for migration issues
- 📦 Automatically detects modules and scores each one independently
- 📋 21 built-in Swift 6 concurrency rules
- 💬 Inline suppression comments (`// swift6-analyzer: ignore`)
- 📊 6 report formats: Markdown, JSON, HTML dashboard, SARIF, Xcode, Diff
- ⚡ Parallel module analysis for fast scans on large codebases
- 🚦 `--fail-on-errors` flag for CI pipelines
- ⚙️ Configurable via `.swift6-analyzer.json` project config file
- 📏 Baseline / diff mode to track progress across runs
- 🧩 Extensible rule architecture — add your own rules by conforming to `Rule`

---

## Requirements

- Swift 6.0+
- macOS 13+

---

## Build

```bash
git clone <repo-url>
cd Swift6-migration
swift build -c release
```

The compiled binary will be at `.build/release/Swift6MigrationAnalyzer`.

### macOS App

Build a local SwiftUI `.app` wrapper:

```bash
./scripts/build-mac-app.sh
open ".build/app/Swift 6 Migration Analyzer.app"
```

The app uses the same analyzer core as the CLI. It lets you choose a Swift
project or file, run the scan, review modules and findings, and export
Markdown, JSON, or HTML reports.

---

## Usage

```bash
swift6-analyzer <path> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<path>` | Path to a Swift project directory or a single `.swift` file |

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--report <format>` | Report format — repeatable for multiple outputs: `markdown`, `json`, `html`, `sarif`, `xcode`, `diff` | `markdown` |
| `--output <file>` | Write the report to a file (required when using multiple `--report` values) | stdout |
| `--exclude <dirs>` | Comma-separated list of directory names to skip | _(none)_ |
| `--fail-on-errors` | Exit with code 1 if any error-severity findings are detected | disabled |
| `--max-depth <n>` | Maximum module nesting depth to scan | `4` |
| `--include-tests` | Include `Tests` and `SnapshotTests` directories (excluded by default) | disabled |
| `--config <file>` | Path to a `.swift6-analyzer.json` config file (auto-detected at project root) | _(auto)_ |
| `--baseline <file>` | Path to a previous JSON report for diff mode | _(none)_ |
| `--save-baseline <file>` | Save the current run as a baseline JSON file | _(none)_ |
| `--verbose` | Print per-phase and per-module timing to stderr | disabled |
| `--version` | Print the tool version and exit | — |

---

## Examples

### Analyze a project and print a Markdown report to stdout

```bash
.build/release/swift6-analyzer /path/to/MyApp
```

### Save a Markdown report to a file

```bash
.build/release/swift6-analyzer /path/to/MyApp \
  --report markdown \
  --output migration-report.md
```

### Generate a JSON report

```bash
.build/release/swift6-analyzer /path/to/MyApp \
  --report json \
  --output report.json
```

### Generate an HTML dashboard

```bash
.build/release/swift6-analyzer /path/to/MyApp \
  --report html \
  --output report.html
```

### Exclude additional directories

```bash
.build/release/swift6-analyzer /path/to/MyApp \
  --exclude Mocks,Stubs,Generated \
  --report html \
  --output report.html-rules \
  --report markdown
```

### Analyze a single file

```bash
.build/release/swift6-analyzer Sources/MyApp/HomeViewModel.swift
```

---

## Default Exclusions

The following directories are automatically excluded from scanning:

| Directory |
|-----------|
| `Pods` |
| `Carthage` |
| `DerivedData` |
| `build` |
| `.build` |
| `.git` |
| `Tests` |
| `SnapshotTests` |

Use `--exclude` to add more on top of these defaults.

---

## Suppressing Findings

Add a suppression comment to silence a finding on a specific line without disabling the rule globally.

### Suppress all rules on a line

```swift
var sharedCache: [String: Any] = [:] // swift6-analyzer: ignore
```

### Suppress a specific rule on a line

```swift
var sharedCache: [String: Any] = [:] // swift6-analyzer: ignore GlobalMutableStateRule
```

### Suppress from the line above

```swift
// swift6-analyzer: ignore GlobalMutableStateRule
var sharedCache: [String: Any] = [:]
```

Suppression comments are case-sensitive. The exact prefix `swift6-analyzer: ignore` is required.

---

## Built-in Rules

> **Weight** — complexity of the required fix (1.0 = full architectural redesign, 0.3 = trivial substitution). The migration **score** for a module = `Σ(finding × weight)`. A score of `0.0` means the module is fully migrated.

### Swift 6 Concurrency Rules (default)

| Rule | Severity | Weight | Detects |
|------|----------|--------|---------|
| [📖 `UncheckedSendableRule`](Docs/Rules/UncheckedSendableRule.md) | 🔴 error | 1.0 | `@unchecked Sendable` — bypasses all concurrency checks |
| [📖 `NonisolatedUnsafeRule`](Docs/Rules/NonisolatedUnsafeRule.md) | 🔴 error | 0.9 | `nonisolated(unsafe)` stored properties |
| [📖 `GlobalMutableStateRule`](Docs/Rules/GlobalMutableStateRule.md) | 🔴 error | 0.9 | Global `var` not concurrency-safe |
| [📖 `SynchronizationPrimitiveRule`](Docs/Rules/SynchronizationPrimitiveRule.md) | ⚠️ warning | 0.8 | `NSLock`, `DispatchSemaphore`, `os_unfair_lock`, etc. |
| [📖 `ThreadRule`](Docs/Rules/ThreadRule.md) | ⚠️ warning | 0.7 | `Thread.detachNewThread`, `Thread.isMainThread`, `Thread.main` |
| [📖 `DispatchQueueRule`](Docs/Rules/DispatchQueueRule.md) | ⚠️ warning / 🔴 error | 0.7 | `DispatchQueue.main.async { }`, `.sync { }` |
| [📖 `ActorReentrancyRule`](Docs/Rules/ActorReentrancyRule.md) | ⚠️ warning | 0.7 | `async` actor methods awaiting external calls — reentrancy risk |
| [📖 `MainActorRunRule`](Docs/Rules/MainActorRunRule.md) | 🔴 error | 0.7 | `await MainActor.run { self }` on non-Sendable class — data race |
| [📖 `OperationQueueMainRule`](Docs/Rules/OperationQueueMainRule.md) | ⚠️ warning | 0.7 | `OperationQueue.main` |
| [📖 `CombineRule`](Docs/Rules/CombineRule.md) | ⚠️ warning | 0.6 | `.sink { }`, `assign(to:on:)`, `AnyCancellable` |
| [📖 `DispatchGroupRule`](Docs/Rules/DispatchGroupRule.md) | ⚠️ warning | 0.6 | `DispatchGroup()` usage |
| [📖 `TaskDetachedRule`](Docs/Rules/TaskDetachedRule.md) | ⚠️ warning | 0.6 | `Task.detached { }` |
| [📖 `MainActorMissingRule`](Docs/Rules/MainActorMissingRule.md) | ⚠️ warning | 0.6 | UIKit/AppKit subclasses missing `@MainActor` |
| [📖 `AsyncSequenceRule`](Docs/Rules/AsyncSequenceRule.md) | ⚠️ warning | 0.5 | `PassthroughSubject` / `CurrentValueSubject` → `AsyncStream` candidates |
| [📖 `TimerRule`](Docs/Rules/TimerRule.md) | ⚠️ warning | 0.5 | Callback-based `Timer.scheduledTimer` / `Timer(timeInterval:…)` |
| [📖 `ObservableObjectRule`](Docs/Rules/ObservableObjectRule.md) | ⚠️ warning | 0.5 | `ObservableObject` + `@Published` |
| [📖 `CompletionHandlerRule`](Docs/Rules/CompletionHandlerRule.md) | ⚠️ warning | 0.5 | `completion: @escaping (...)` |
| [📖 `CheckedContinuationRule`](Docs/Rules/CheckedContinuationRule.md) | ⚠️ warning | 0.5 | `withUnsafeContinuation` / `withUnsafeThrowingContinuation` |
| [📖 `PreconcurrencyRule`](Docs/Rules/PreconcurrencyRule.md) | ⚠️ warning | 0.4 | `@preconcurrency import …` and `@preconcurrency` conformances |
| [📖 `NotificationCenterRule`](Docs/Rules/NotificationCenterRule.md) | ⚠️ warning | 0.4 | `NotificationCenter.addObserver` / `.post` |
| [📖 `WithUnsafeCurrentTaskRule`](Docs/Rules/WithUnsafeCurrentTaskRule.md) | ⚠️ warning | 0.4 | Deprecated `Task.current` / `withUnsafeCurrentTask` |


---

## Rule Documentation

Each rule has a dedicated documentation page with:
- What the rule detects
- Why it matters in Swift 6
- ❌ Wrong code example
- ✅ Correct code example(s) with migration guidance

### Swift 6 Concurrency

| Rule | Summary |
|------|---------|
| [UncheckedSendableRule](Docs/Rules/UncheckedSendableRule.md) | Types bypassing `Sendable` checks with `@unchecked` |
| [NonisolatedUnsafeRule](Docs/Rules/NonisolatedUnsafeRule.md) | Properties suppressing concurrency checking with `nonisolated(unsafe)` |
| [GlobalMutableStateRule](Docs/Rules/GlobalMutableStateRule.md) | File-scope `var` with no actor isolation |
| [SynchronizationPrimitiveRule](Docs/Rules/SynchronizationPrimitiveRule.md) | Manual locks replacing actor isolation |
| [ThreadRule](Docs/Rules/ThreadRule.md) | `Thread` API bypassing the actor model |
| [DispatchQueueRule](Docs/Rules/DispatchQueueRule.md) | `DispatchQueue` usage not integrated with actors |
| [ActorReentrancyRule](Docs/Rules/ActorReentrancyRule.md) | Actor methods awaiting external calls — reentrancy risk |
| [OperationQueueMainRule](Docs/Rules/OperationQueueMainRule.md) | `OperationQueue.main` instead of `@MainActor` |
| [CombineRule](Docs/Rules/CombineRule.md) | Combine subscriptions with no actor isolation guarantee |
| [DispatchGroupRule](Docs/Rules/DispatchGroupRule.md) | `DispatchGroup` instead of `withTaskGroup` |
| [TaskDetachedRule](Docs/Rules/TaskDetachedRule.md) | `Task.detached` losing actor context |
| [MainActorMissingRule](Docs/Rules/MainActorMissingRule.md) | UIKit/AppKit subclasses without explicit `@MainActor` |
| [MainActorRunRule](Docs/Rules/MainActorRunRule.md) | `await MainActor.run { self }` on a non-Sendable class — Swift 6 compile error |
| [TimerRule](Docs/Rules/TimerRule.md) | Callback `Timer` firing outside actor isolation |
| [ObservableObjectRule](Docs/Rules/ObservableObjectRule.md) | `ObservableObject` + `@Published` instead of `@Observable` |
| [CompletionHandlerRule](Docs/Rules/CompletionHandlerRule.md) | `@escaping` completion handlers ready for `async/await` |
| [PreconcurrencyRule](Docs/Rules/PreconcurrencyRule.md) | `@preconcurrency` suppressing real Swift 6 errors |
| [NotificationCenterRule](Docs/Rules/NotificationCenterRule.md) | `NotificationCenter` crossing actor boundaries |
| [CheckedContinuationRule](Docs/Rules/CheckedContinuationRule.md) | `withUnsafeContinuation` skipping resume-count validation |
| [AsyncSequenceRule](Docs/Rules/AsyncSequenceRule.md) | Combine subjects ready for `AsyncStream` migration |
| [WithUnsafeCurrentTaskRule](Docs/Rules/WithUnsafeCurrentTaskRule.md) | Deprecated low-level task APIs |

---

## Report Formats

### Markdown

Grouped by module and rule, with severity badges and a summary table.

```markdown
# Swift 6 Migration Report

Generated: 5/8/2026

**Total findings:** 4

## DispatchQueueRule

- ⚠️ `HomeViewModel.swift:22` — Prefer @MainActor or structured concurrency over DispatchQueue.main.async

## Summary

| Rule | Errors | Warnings | Infos |
|------|--------|----------|-------|
| DispatchQueueRule | 0 | 1 | 0 |
```

### JSON

Machine-readable output, suitable for CI pipelines.

```json
{
  "findings": [
    {
      "column": 8,
      "file": "/path/to/HomeViewModel.swift",
      "line": 22,
      "message": "Prefer @MainActor or structured concurrency over DispatchQueue.main.async",
      "rule": "DispatchQueueRule",
      "severity": "warning"
    }
  ],
  "generatedAt": "2026-05-08T09:00:00Z",
  "totalFindings": 1
}
```

### HTML

Interactive dashboard with:
- Summary cards (total, errors, warnings, infos)
- Findings grouped by rule
- Sortable table of all findings (click any column header to sort)

### SARIF

[Static Analysis Results Interchange Format](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html) — standard format accepted by GitHub Advanced Security. Upload to a repository to display findings as **inline annotations on pull-request diffs** and in the **Security tab**.

```bash
.build/release/swift6-analyzer /path/to/MyApp \
  --report sarif \
  --output results.sarif

# Upload via GitHub CLI
gh code-scanning upload-sarif --sarif results.sarif
```

### Xcode

Outputs one line per finding in Xcode's diagnostic format. Use as a build phase script to see findings as **inline issue markers** inside Xcode.

```
/absolute/path/File.swift:22:8: warning: [DispatchQueueRule] Prefer @MainActor or structured concurrency over DispatchQueue.main.async
/absolute/path/File.swift:45:4: error: [GlobalMutableStateRule] Global variable 'cache' is not concurrency-safe
```

**Xcode build phase script:**
```bash
ANALYZER=".build/release/swift6-analyzer"
if [ -f "$ANALYZER" ]; then
  "$ANALYZER" "$SRCROOT" --report xcode
fi
```

### Diff

Compares the current run against a saved baseline JSON and shows new regressions, resolved findings, and score deltas per module.

```bash
# Save a baseline
.build/release/swift6-analyzer /path/to/MyApp --report json --output baseline.json

# Later: compare against it
.build/release/swift6-analyzer /path/to/MyApp \
  --baseline baseline.json \
  --report diff \
  --output delta.md
```

### Multiple formats in one run

Pass `--report` multiple times. Requires `--output <stem>`:

```bash
.build/release/swift6-analyzer /path/to/MyApp \
  --report html --report json \
  --output report
# writes report.html and report.json
```

---

## Config File

Create `.swift6-analyzer.json` at your project root for persistent settings (no flags needed on every run):

```json
{
  "exclude": ["Mocks", "Generated", "Stubs"],
  "maxDepth": 3,
  "includeTests": false,
  "disabledRules": ["ObservableObjectRule"],
  "severityOverrides": {
    "CompletionHandlerRule": "info"
  },
  "report": ["html", "json"],
  "saveBaseline": "baseline.json"
}
```

CLI flags always override config file values. Use `--config <path>` to point to a non-default location.

---

## Adding a Custom Rule

1. Create a new file in `Sources/Swift6MigrationAnalyzerCore/Rules/`.
2. Conform to the `Rule` protocol:

```swift
import SwiftSyntax

struct MyCustomRule: Rule {
    var name: String { "MyCustomRule" }

    func analyze(
        tree: SourceFileSyntax,
        file: String,
        locationConverter: SourceLocationConverter
    ) -> [Finding] {
        let visitor = Visitor(file: file, converter: locationConverter)
        visitor.walk(tree)
        return visitor.findings
    }

    private final class Visitor: SyntaxVisitor {
        var findings: [Finding] = []
        let file: String
        let converter: SourceLocationConverter

        init(file: String, converter: SourceLocationConverter) {
            self.file = file
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            let (line, col) = SourceLocationHelper.location(of: node, converter: converter)
            findings.append(Finding(
                file: file, line: line, column: col,
                severity: .warning,
                rule: "MyCustomRule",
                message: "Describe the issue and suggestion here"
            ))
            return .visitChildren
        }
    }
}
```

3. Register it in [`Analyzer.swift`](Sources/Swift6MigrationAnalyzerCore/Core/Analyzer.swift) inside `defaultRules`.
4. Add a weight entry in [`FindingComplexity.swift`](Sources/Swift6MigrationAnalyzerCore/Core/FindingComplexity.swift).
5. Create a doc file at `Docs/Rules/MyCustomRule.md` following the same template as the existing rule docs.

---

## Project Structure

```
Docs/
└── Rules/                                ← Per-rule documentation with ❌/✅ examples
    ├── GlobalMutableStateRule.md
    ├── ActorReentrancyRule.md
    ├── AsyncSequenceRule.md
    ├── WithUnsafeCurrentTaskRule.md
    └── ... (23 files total)
Sources/
├── Swift6MigrationAnalyzer/
│   ├── main.swift                        ← Entry point
│   └── CLI.swift                         ← ArgumentParser command & flags
└── Swift6MigrationAnalyzerCore/
    ├── Core/
    │   ├── Severity.swift
    │   ├── Finding.swift
    │   ├── Rule.swift
    │   ├── Analyzer.swift
    │   ├── ModuleScanner.swift
    │   ├── ModuleResult.swift
    │   ├── MigrationStatus.swift
    │   ├── FindingComplexity.swift
    │   ├── BaselineComparator.swift
    │   └── MigrationIndicators.swift
    ├── Rules/                            ← 21 rule implementations (each links to Docs/Rules/)
    │   ├── GlobalMutableStateRule.swift
    │   ├── ActorReentrancyRule.swift
    │   ├── AsyncSequenceRule.swift
    │   ├── WithUnsafeCurrentTaskRule.swift
    │   └── ... (21 files total)
    ├── Reporters/
    │   ├── Reporter.swift
    │   ├── MarkdownReporter.swift
    │   ├── JSONReporter.swift
    │   ├── HTMLReporter.swift
    │   ├── SARIFReporter.swift
    │   ├── XcodeReporter.swift
    │   ├── DiffReporter.swift
    │   └── AssistantReporter.swift
    └── Utils/
        ├── FileScanner.swift
        ├── AnalyzerConfig.swift
        ├── SourceLocationHelper.swift
        ├── PackageManifestParser.swift
        └── SuppressionFilter.swift
```

---

## License

MIT
