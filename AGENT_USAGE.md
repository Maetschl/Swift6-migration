# Swift 6 Migration Analyzer — Agent Usage Guide

> **Purpose:** This document is intended to be read by an AI coding agent. It contains all the information needed to install, run, interpret, and act on the Swift 6 Migration Analyzer tool inside any Swift project.

---

## What This Tool Does

`swift6-analyzer` scans a Swift codebase and identifies code patterns that will cause **compile errors or behavioral issues under Swift 6 strict concurrency**. It:

- Detects concurrency anti-patterns (global mutable state, DispatchQueue, missing `@MainActor`, etc.)
- Auto-detects Swift Package Manager modules within the project and scores each one
- Assigns each module a **migration score** (higher = more work needed; `0.0` = fully migrated)
- Outputs reports in Markdown, JSON, or HTML

The tool is **read-only** — it never modifies any source files.

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS | 13+ |
| Swift toolchain | 6.0+ |

---

## Step 1 — Clone and Build

```bash
git clone https://github.com/<owner>/Swift6-migration.git
cd Swift6-migration
swift build -c release
```

The compiled binary will be at:

```
.build/release/swift6-analyzer
```

Optionally install it system-wide:

```bash
cp .build/release/swift6-analyzer /usr/local/bin/swift6-analyzer
```

---

## Step 2 — Run on the Target Project

### Analyze an entire project (recommended)

```bash
swift6-analyzer /path/to/TargetProject
```

### Analyze a single file

```bash
swift6-analyzer /path/to/TargetProject/Sources/MyFeature/ViewModel.swift
```

### Save a JSON report (best for agent processing)

```bash
swift6-analyzer /path/to/TargetProject \
  --report json \
  --output swift6-report.json
```

### Save a SARIF report (GitHub code scanning)

```bash
swift6-analyzer /path/to/TargetProject \
  --report sarif \
  --output results.sarif
# Upload via GitHub CLI:
# gh code-scanning upload-sarif --sarif results.sarif
```

### Fail CI on error-severity findings

```bash
swift6-analyzer /path/to/TargetProject --fail-on-errors
```

### Save a Markdown report

```bash
swift6-analyzer /path/to/TargetProject \
  --report markdown \
  --output swift6-report.md
```

### Exclude directories you don't own

```bash
swift6-analyzer /path/to/TargetProject \
  --exclude Mocks,Generated,Stubs \
  --report json \
  --output swift6-report.json
```

---

## Step 3 — Understand the Output

### stderr (progress summary — always printed, not in report file)

```
🔍 Detecting modules in /path/to/TargetProject...
📦 3 module(s) · 42 file(s)

  ⏳ FeatureA                           score:6.30  findings:9  [actors:0 @MainActor:1 async:2]
  ⏳ FeatureB                           score:3.20  findings:5  [actors:1 @MainActor:2 async:4]
  ✅ FeatureC                           score:0.00  findings:0  [actors:2 @MainActor:5 async:8]

📊 Total findings: 14  |  Project score: 9.50
   ✅ Migrated: 1  ⏳ Pending: 2
```

**How to interpret the score:**

The score is calculated as:

```
module score = SUM(finding × complexity weight)
```

Each finding contributes a weight between `0.3` (trivial fix) and `1.0` (deep architectural change). Because of this, the score is **unbounded** — a module with many findings can reach any value.

- A score of `0.0` means the module is fully migrated — no issues found.
- **Do not use absolute thresholds** to classify effort. A module with score `8.0` is not inherently "high effort" — it depends on the project.
- Use scores to **compare modules within the same project**: a module with score `12.0` requires roughly 4× more effort than one with score `3.0`.

> ⚠️ The **Project score** at the bottom is a sum of all module scores and is **not** comparable across different projects. A large project with many modules will naturally produce a much higher total. Use it only to track progress over time within the same project.

**Migration indicators** (shown in `[…]`):
- `actors:N` — number of `actor` declarations already in the module
- `@MainActor:N` — number of `@MainActor` annotations already present
- `async:N` — number of `async` functions already present

A high indicator count relative to findings means the module is partially migrated.

---

### JSON report structure

```json
{
  "projectName": "TargetProject",
  "generatedAt": "2026-05-08T10:00:00Z",
  "totalFindings": 14,
  "totalScore": 9.50,
  "modules": [
    {
      "name": "FeatureA",
      "path": "/path/to/TargetProject/Sources/FeatureA",
      "status": "pendingMigration",
      "score": 6.30,
      "fileCount": 18,
      "totalLinesOfCode": 1240,
      "findings": [
        {
          "file": "/path/to/TargetProject/Sources/FeatureA/HomeViewModel.swift",
          "line": 22,
          "column": 8,
          "severity": "warning",
          "rule": "DispatchQueueRule",
          "message": "Prefer @MainActor or structured concurrency over DispatchQueue.main.async"
        }
      ],
      "migrationIndicators": {
        "actorDeclarationCount": 0,
        "mainActorAnnotationCount": 1,
        "asyncFunctionCount": 2
      }
    }
  ]
}
```

**Key fields an agent should use:**
- `modules[].status` — `"migrated"` or `"pendingMigration"`
- `modules[].score` — prioritize high-score modules first
- `modules[].findings[].rule` — determines what fix to apply (see rule table below)
- `modules[].findings[].file` + `.line` + `.column` — exact location to fix
- `modules[].findings[].message` — human-readable description of the issue

---

## Step 4 — Apply Fixes

Use the findings to guide code changes. The table below maps each rule to the correct Swift 6 fix pattern.

### Rule → Fix Reference Table

| Rule | Severity | Complexity Weight | Pattern Detected | Correct Fix |
|------|----------|-------------------|-----------------|-------------|
| `UncheckedSendableRule` | 🔴 error | 1.0 | `@unchecked Sendable` | Audit thread safety of every mutable property; replace with a proper `actor` or add `nonisolated(unsafe)` only if proven safe |
| `GlobalMutableStateRule` | 🔴 error | 0.9 | `var` at global/file scope | Add `@MainActor` to the variable, wrap it inside an `actor`, or convert it to a `let` constant |
| `SynchronizationPrimitiveRule` | ⚠️ warning | 0.8 | `NSLock`, `DispatchSemaphore`, `os_unfair_lock`, `NSRecursiveLock` | Replace with an `actor` that owns the protected state |
| `DispatchQueueRule` | ⚠️ warning / 🔴 error | 0.7 | `DispatchQueue.main.async {}` → warning; `DispatchQueue.*.sync {}` → error | Replace with `Task { @MainActor in … }` or annotate enclosing type with `@MainActor` |
| `ActorReentrancyRule` | ⚠️ warning | 0.7 | `async` actor method containing `await` on external call | Snapshot any actor state needed before the `await`; validate invariants after resuming |
| `OperationQueueMainRule` | ⚠️ warning | 0.7 | `OperationQueue.main.addOperation {}` | Replace with `Task { @MainActor in … }` |
| `TaskDetachedRule` | ⚠️ warning | 0.6 | `Task.detached { }` | Prefer `Task { }` (inherits actor context); only use `Task.detached` if explicit isolation escape is intentional |
| `MainActorMissingRule` | ⚠️ warning | 0.6 | `UIViewController`, `UIView`, `NSViewController`, `NSView` subclass without `@MainActor` | Add `@MainActor` to the class declaration |
| `AsyncSequenceRule` | ⚠️ warning | 0.5 | `PassthroughSubject<T,E>`, `CurrentValueSubject<T,E>` | Replace with `AsyncStream` / `AsyncThrowingStream`; consumers use `for await` |
| `ObservableObjectRule` | ⚠️ warning | 0.5 | `class … : ObservableObject` with `@Published` properties | Migrate to `@Observable` macro (requires `import Observation`; remove `ObservableObject` conformance and `@Published`) |
| `CompletionHandlerRule` | ⚠️ warning | 0.5 | Function parameter `completion: @escaping (…) -> Void` | Refactor function to `async` / `await`; update all call-sites |
| `NotificationCenterRule` | ⚠️ warning | 0.4 | `NotificationCenter.default.addObserver` closure or `.post` | For observers: use `NotificationCenter.default.notifications(named:).for(object:)` async sequence; annotate posting code with `@MainActor` if UI-related |
| `WithUnsafeCurrentTaskRule` | ⚠️ warning | 0.4 | `withUnsafeCurrentTask { }`, `Task.current` | Replace with `withTaskCancellationHandler` or `Task.checkCancellation()` |

> **Complexity weight** indicates how much effort the fix typically requires (1.0 = full architectural redesign, 0.3 = trivial substitution). Prioritize high-weight findings first.

---

## Step 5 — Recommended Agent Workflow

Follow this workflow when using the tool to drive migration:

```
1. BUILD the tool          → swift build -c release (in the analyzer repo)
2. RUN on target project   → swift6-analyzer <project-path> --report json --output report.json
3. PARSE report.json       → read modules[], sort by score descending
4. FOR EACH module (high score first):
     a. List findings sorted by complexity weight (descending)
     b. Apply fix patterns from the Rule → Fix Reference Table
     c. Re-run swift6-analyzer on that module/file to confirm score dropped
5. REPEAT until all module scores = 0.0
6. RUN swift build on the target project with Swift 6 strict concurrency enabled to confirm
```

### Enable Swift 6 strict concurrency in the target project

Add to the target's `Package.swift` to verify fixes compile correctly:

```swift
.target(
    name: "YourTarget",
    swiftSettings: [
        .swiftLanguageMode(.v6)
    ]
)
```

Or for Xcode projects: set **Swift Language Version** to **Swift 6** in Build Settings, and set **Strict Concurrency Checking** to **Complete**.

---

## CLI Reference (Quick Summary)

```
USAGE: swift6-analyzer <path> [options]

ARGUMENTS:
  <path>                    Path to a Swift project directory or a single .swift file

OPTIONS:
  --exclude <dirs>          Comma-separated directory names to skip (added on top of built-in exclusions)
  --report <format>         markdown | json | html | sarif | xcode | diff  (default: markdown, repeatable)
  --output <file>           Write report to file; required when multiple --report values are given
  --fail-on-errors          Exit with code 1 if any .error-severity findings are detected
  --max-depth <n>           Maximum module nesting depth to scan (default: 4)
  --include-tests           Include Tests and SnapshotTests directories (excluded by default)
  --config <file>           Path to .swift6-analyzer.json config file (auto-detected at project root)
  --baseline <file>         Path to a previous JSON report for diff mode
  --save-baseline <file>    Save the current run as a baseline JSON file
  --verbose                 Print per-phase and per-module timing to stderr
  --version                 Print tool version (1.2.0) and exit

BUILT-IN EXCLUDED DIRECTORIES (always skipped unless --include-tests):
  Pods, Carthage, DerivedData, build, .build, .git
  Tests, SnapshotTests, *Tests, *Test  (suppressed by --include-tests)
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Tool ran successfully (findings may still exist unless `--fail-on-errors` is set) |
| `1` | Fatal error (path not found, unreadable file, etc.) OR `--fail-on-errors` triggered |

Without `--fail-on-errors` the tool exits `0` even when findings exist. Use `--fail-on-errors` to make CI pipelines fail automatically on any `.error`-severity finding:

```bash
swift6-analyzer /path/to/MyApp --fail-on-errors
```

To fail only when the score exceeds a threshold, parse the JSON report and check `totalScore` yourself.

---

## CI Integration Example

```bash
#!/bin/bash
set -e

# Build analyzer
cd /path/to/Swift6-migration
swift build -c release 2>/dev/null
ANALYZER=".build/release/swift6-analyzer"

# Run on target project
$ANALYZER /path/to/MyApp \
  --report json \
  --output /tmp/swift6-report.json 2>/dev/null

# Fail CI if any pending-migration modules exist
PENDING=$(jq '[.modules[] | select(.status == "pendingMigration")] | length' /tmp/swift6-report.json)
if [ "$PENDING" -gt 0 ]; then
  echo "❌ $PENDING module(s) are not Swift 6 ready."
  jq '.modules[] | select(.status == "pendingMigration") | {module: .name, score: .score, findings: (.findings | length)}' /tmp/swift6-report.json
  exit 1
fi

echo "✅ All modules are Swift 6 ready."
```

---

## Notes for Agents

- **The tool only reads files** — it is safe to run at any time without risk of side effects.
- **Re-run after each batch of fixes** to get an updated score and confirm progress.
- **stderr vs stdout**: progress/summary goes to stderr; the report content goes to stdout (or the `--output` file). When parsing programmatically always use `--output <file>` and read the file.
- **Findings are sorted by file path and line number** within each module — not by severity or weight. Always re-sort by weight before prioritizing fixes.
- **A zero score does not guarantee Swift 6 compilation success** — it means no *detected* patterns were found. Always do a final `swift build` with `.swiftLanguageMode(.v6)` enabled to confirm.
- **`Tests` is excluded by default.** If you want to also migrate test targets, add them explicitly or remove them from the exclusion list (not currently configurable; requires source change in `FileScanner.swift`).
