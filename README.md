# Swift 6 Migration Analyzer

A command-line tool to analyze Swift 5 codebases and detect patterns that need attention when migrating to Swift 6. Built with SwiftSyntax for accurate, syntax-based analysis.

---

## Features

- 🔍 Recursively scans Swift projects for migration issues
- 📦 Automatically detects modules and scores each one independently
- 📋 16 built-in Swift 6 concurrency rules + 2 optional code-quality rules
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

> **Weight** — complexity of the required fix (1.0 = full architectural redesign, 0.3 = trivial substitution). The migration **score** for a module = `Σ(finding × weight)`. A score of `0.0` means the module is fully migrated.

### Swift 6 Concurrency Rules (default)

| Rule | Severity | Weight | Detects | Docs |
|------|----------|--------|---------|------|
| `UncheckedSendableRule` | 🔴 error | 1.0 | `@unchecked Sendable` — bypasses all concurrency checks | [📖](Docs/Rules/UncheckedSendableRule.md) |
| `NonisolatedUnsafeRule` | 🔴 error | 0.9 | `nonisolated(unsafe)` stored properties | [📖](Docs/Rules/NonisolatedUnsafeRule.md) |
| `GlobalMutableStateRule` | 🔴 error | 0.9 | Global `var` not concurrency-safe | [📖](Docs/Rules/GlobalMutableStateRule.md) |
| `SynchronizationPrimitiveRule` | ⚠️ warning | 0.8 | `NSLock`, `DispatchSemaphore`, `os_unfair_lock`, etc. | [📖](Docs/Rules/SynchronizationPrimitiveRule.md) |
| `ThreadRule` | ⚠️ warning | 0.7 | `Thread.detachNewThread`, `Thread.isMainThread`, `Thread.main` | [📖](Docs/Rules/ThreadRule.md) |
| `DispatchQueueRule` | ⚠️ warning / 🔴 error | 0.7 | `DispatchQueue.main.async { }`, `.sync { }` | [📖](Docs/Rules/DispatchQueueRule.md) |
| `OperationQueueMainRule` | ⚠️ warning | 0.7 | `OperationQueue.main` | [📖](Docs/Rules/OperationQueueMainRule.md) |
| `CombineRule` | ⚠️ warning | 0.6 | `.sink { }`, `assign(to:on:)`, `AnyCancellable` | [📖](Docs/Rules/CombineRule.md) |
| `DispatchGroupRule` | ⚠️ warning | 0.6 | `DispatchGroup()` usage | [📖](Docs/Rules/DispatchGroupRule.md) |
| `TaskDetachedRule` | ⚠️ warning | 0.6 | `Task.detached { }` | [📖](Docs/Rules/TaskDetachedRule.md) |
| `MainActorMissingRule` | ⚠️ warning | 0.6 | UIKit/AppKit subclasses missing `@MainActor` | [📖](Docs/Rules/MainActorMissingRule.md) |
| `TimerRule` | ⚠️ warning | 0.5 | Callback-based `Timer.scheduledTimer` / `Timer(timeInterval:…)` | [📖](Docs/Rules/TimerRule.md) |
| `ObservableObjectRule` | ⚠️ warning | 0.5 | `ObservableObject` + `@Published` | [📖](Docs/Rules/ObservableObjectRule.md) |
| `CompletionHandlerRule` | ⚠️ warning | 0.5 | `completion: @escaping (...)` | [📖](Docs/Rules/CompletionHandlerRule.md) |
| `PreconcurrencyRule` | ⚠️ warning | 0.4 | `@preconcurrency import …` and `@preconcurrency` conformances | [📖](Docs/Rules/PreconcurrencyRule.md) |
| `NotificationCenterRule` | ⚠️ warning | 0.4 | `NotificationCenter.addObserver` / `.post` | [📖](Docs/Rules/NotificationCenterRule.md) |

### Code-Quality Rules (opt-in via `--include-quality-rules`)

| Rule | Severity | Weight | Detects | Docs |
|------|----------|--------|---------|------|
| `ForceTryRule` | 🔴 error | 0.8 | `try!` | [📖](Docs/Rules/ForceTryRule.md) |
| `ForceUnwrapRule` | ⚠️ warning | 0.3 | `value!` | [📖](Docs/Rules/ForceUnwrapRule.md) |

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
| [OperationQueueMainRule](Docs/Rules/OperationQueueMainRule.md) | `OperationQueue.main` instead of `@MainActor` |
| [CombineRule](Docs/Rules/CombineRule.md) | Combine subscriptions with no actor isolation guarantee |
| [DispatchGroupRule](Docs/Rules/DispatchGroupRule.md) | `DispatchGroup` instead of `withTaskGroup` |
| [TaskDetachedRule](Docs/Rules/TaskDetachedRule.md) | `Task.detached` losing actor context |
| [MainActorMissingRule](Docs/Rules/MainActorMissingRule.md) | UIKit/AppKit subclasses without explicit `@MainActor` |
| [TimerRule](Docs/Rules/TimerRule.md) | Callback `Timer` firing outside actor isolation |
| [ObservableObjectRule](Docs/Rules/ObservableObjectRule.md) | `ObservableObject` + `@Published` instead of `@Observable` |
| [CompletionHandlerRule](Docs/Rules/CompletionHandlerRule.md) | `@escaping` completion handlers ready for `async/await` |
| [PreconcurrencyRule](Docs/Rules/PreconcurrencyRule.md) | `@preconcurrency` suppressing real Swift 6 errors |
| [NotificationCenterRule](Docs/Rules/NotificationCenterRule.md) | `NotificationCenter` crossing actor boundaries |

### Code Quality (opt-in)

| Rule | Summary |
|------|---------|
| [ForceTryRule](Docs/Rules/ForceTryRule.md) | `try!` crashing instead of proper error handling |
| [ForceUnwrapRule](Docs/Rules/ForceUnwrapRule.md) | `value!` crashing instead of optional binding |

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
    ├── NonisolatedUnsafeRule.md
    ├── UncheckedSendableRule.md
    └── ... (18 files total)
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
    │   └── MigrationIndicators.swift
    ├── Rules/                            ← 18 rule implementations (each links to Docs/Rules/)
    │   ├── GlobalMutableStateRule.swift
    │   ├── NonisolatedUnsafeRule.swift
    │   ├── UncheckedSendableRule.swift
    │   ├── SynchronizationPrimitiveRule.swift
    │   ├── ThreadRule.swift
    │   ├── DispatchQueueRule.swift
    │   ├── OperationQueueMainRule.swift
    │   ├── CombineRule.swift
    │   ├── DispatchGroupRule.swift
    │   ├── TaskDetachedRule.swift
    │   ├── MainActorMissingRule.swift
    │   ├── TimerRule.swift
    │   ├── ObservableObjectRule.swift
    │   ├── CompletionHandlerRule.swift
    │   ├── PreconcurrencyRule.swift
    │   ├── NotificationCenterRule.swift
    │   ├── ForceUnwrapRule.swift          ← quality rule (opt-in)
    │   └── ForceTryRule.swift             ← quality rule (opt-in)
    ├── Reporters/
    │   ├── Reporter.swift
    │   ├── MarkdownReporter.swift
    │   ├── JSONReporter.swift
    │   └── HTMLReporter.swift
    └── Utils/
        ├── FileScanner.swift
        └── SourceLocationHelper.swift
```

---

## License

MIT
