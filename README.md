# Swift 6 Migration Analyzer

A command-line tool to analyze Swift 5 codebases and detect patterns that need attention when migrating to Swift 6. Built with SwiftSyntax for accurate, syntax-based analysis.

---

## Features

- 🔍 Recursively scans Swift projects for migration issues
- 📦 Automatically detects modules and scores each one independently
- 📋 10 built-in Swift 6 concurrency rules + 2 optional code-quality rules
- 📊 3 report formats: Markdown, JSON, HTML dashboard
- ⚙️ Configurable exclusions for directories you don't own
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

The compiled binary will be at `.build/release/swift6-analyzer`.

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
| `--report <format>` | Report format: `markdown`, `json`, or `html` | `markdown` |
| `--output <file>` | Write the report to a file instead of stdout | stdout |
| `--exclude <dirs>` | Comma-separated list of directory names to skip | _(none)_ |
| `--include-quality-rules` | Also enable code-quality rules (`ForceUnwrap`, `ForceTry`) | disabled |

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
  --output report.html
```

### Include optional code-quality rules

```bash
.build/release/swift6-analyzer /path/to/MyApp \
  --include-quality-rules \
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

## Built-in Rules

### Swift 6 Concurrency Rules (default)

| Rule | Severity | Detects | Suggestion |
|------|----------|---------|------------|
| `GlobalMutableStateRule` | 🔴 error | Global `var` not concurrency-safe | Isolate with `@MainActor`, wrap in an actor, or make it a `let` constant |
| `DispatchQueueRule` | ⚠️ warning / 🔴 error | `DispatchQueue.main.async { }`, `.sync { }` | Replace with `@MainActor` or structured concurrency; `.sync` is flagged as an error |
| `TaskDetachedRule` | ⚠️ warning | `Task.detached { }` | Prefer `Task { }` or structured concurrency to avoid actor isolation issues |
| `CompletionHandlerRule` | ⚠️ warning | `completion: @escaping (...)` | Candidate for `async`/`await` migration |
| `UncheckedSendableRule` | 🔴 error | `@unchecked Sendable` | Audit thread safety manually; bypass is not Swift 6 safe |
| `ObservableObjectRule` | ⚠️ warning | `ObservableObject` + `@Published` | Migrate to the `@Observable` macro (Swift 5.9+) |
| `SynchronizationPrimitiveRule` | ⚠️ warning | `NSLock`, `DispatchSemaphore`, `os_unfair_lock`, etc. | Consider migrating to an actor for Swift 6 data isolation |
| `MainActorMissingRule` | ⚠️ warning | UI classes (`UIViewController`, `UIView`, …) missing `@MainActor` | Add `@MainActor` to make main-thread isolation explicit |
| `NotificationCenterRule` | ⚠️ warning | `NotificationCenter.addObserver` closure / `.post` | Use `NotificationCenter.notifications(named:)` async sequence or annotate with `@MainActor` |
| `OperationQueueMainRule` | ⚠️ warning | `OperationQueue.main` | Replace with `@MainActor` isolation or `Task { @MainActor in ... }` |

### Code-Quality Rules (opt-in via `--include-quality-rules`)

| Rule | Severity | Detects | Suggestion |
|------|----------|---------|------------|
| `ForceUnwrapRule` | ⚠️ warning | `value!` | Use optional binding (`if let`, `guard let`) instead |
| `ForceTryRule` | 🔴 error | `try!` | Use `try/catch` or `try?` instead |

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
            // Detection logic here
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

3. Register it in [`Analyzer.swift`](Sources/Swift6MigrationAnalyzerCore/Core/Analyzer.swift) inside `defaultRules`:

```swift
public static var defaultRules: [any Rule] {
    [
        // ...existing rules...
        MyCustomRule()
    ]
}
```

---

## Project Structure

```
Sources/
├── Swift6MigrationAnalyzer/
│   ├── main.swift                        ← Entry point
│   └── CLI.swift                         ← ArgumentParser command & flags
└── Swift6MigrationAnalyzerCore/
    ├── Core/
    │   ├── Severity.swift                ← info / warning / error enum
    │   ├── Finding.swift                 ← Codable result model
    │   ├── Rule.swift                    ← Rule protocol
    │   ├── Analyzer.swift                ← Engine: parse → run rules → aggregate
    │   ├── ModuleScanner.swift           ← Detects modules inside a directory
    │   ├── ModuleResult.swift            ← Per-module findings + score + status
    │   ├── MigrationStatus.swift         ← Migrated / PendingMigration
    │   ├── FindingComplexity.swift       ← Complexity scoring weights
    │   └── MigrationIndicators.swift     ← Counts actors, @MainActor, async funcs
    ├── Rules/
    │   ├── GlobalMutableStateRule.swift
    │   ├── DispatchQueueRule.swift
    │   ├── TaskDetachedRule.swift
    │   ├── CompletionHandlerRule.swift
    │   ├── UncheckedSendableRule.swift
    │   ├── ObservableObjectRule.swift
    │   ├── SynchronizationPrimitiveRule.swift
    │   ├── MainActorMissingRule.swift
    │   ├── NotificationCenterRule.swift
    │   ├── OperationQueueMainRule.swift
    │   ├── ForceUnwrapRule.swift          ← quality rule (opt-in)
    │   └── ForceTryRule.swift             ← quality rule (opt-in)
    ├── Reporters/
    │   ├── Reporter.swift                ← Reporter protocol
    │   ├── MarkdownReporter.swift
    │   ├── JSONReporter.swift
    │   └── HTMLReporter.swift
    └── Utils/
        ├── FileScanner.swift             ← Recursive .swift scanner with exclusions
        └── SourceLocationHelper.swift    ← Wraps SourceLocationConverter
```

---

## License

MIT
