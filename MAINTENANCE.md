# Weekly Maintenance & Audit Plan — Swift 6 Migration Analyzer

> **Purpose:** Step-by-step audit checklist to be executed by an AI coding agent (or a developer)
> once per week. Work through each section in order. Every code change must be followed by a full
> `swift test` run before moving to the next section. Commit after each section that produces changes.

---

## 0 — Pre-flight

Establish a clean baseline before touching anything.

```bash
cd <repo-root>
git pull --rebase
swift build
swift test
```

Record the current test count from the last line of output, for example:

```
✔ Test run with 253 tests in 24 suites passed after 0.047 seconds.
```

> ⚠️ If any tests fail at this point, stop. Fix the regression as an unplanned hotfix commit,
> then restart this plan from step 0.

---

## 1 — Dependency & Language Update

### 1.1 Verify Swift toolchain

```bash
swift --version
```

Compare with the latest stable release at <https://swift.org/download/>.

If a newer stable toolchain is available:

- Bump `swift-tools-version` in `Package.swift` if new SPM or language features are desired.
- Update the `.macOS` platform minimum if required by the new toolchain.
- Run `swift build && swift test` after any `Package.swift` change.

### 1.2 Update package dependencies

```bash
swift package update
```

Review `Package.resolved` for version changes. Critical packages to scrutinise:

| Package | Why it matters |
|---|---|
| `swift-syntax` | Breaking AST API changes are common across minor versions. Check all `SyntaxVisitor`, `SyntaxRewriter`, and node-type usages still compile without deprecation warnings. |
| `swift-argument-parser` | Check for deprecated `@Flag` / `@Option` / `@Argument` APIs. |

Run `swift build && swift test` after the update.

Commit if anything changed:

```
chore(deps): update swift-syntax to X.Y.Z, argument-parser to X.Y.Z
```

---

## 2 — Test Suite Health Check

### 2.1 Identify coverage gaps

Run the test suite, then inspect every source file in `Sources/Swift6MigrationAnalyzerCore/`
and cross-reference it with the test files under `Tests/Swift6MigrationAnalyzerTests/`.

Minimum expected test coverage map:

| Source file | Expected test file |
|---|---|
| `Core/Analyzer.swift` | `Core/AnalyzerTests.swift` |
| `Core/FindingComplexity.swift` | `Core/FindingComplexityTests.swift` |
| `Core/MigrationStatus.swift` | *(no dedicated file today — create one if composite tag logic is untested)* |
| `Core/ModuleScanner.swift` | `Core/ModuleScannerTests.swift` |
| `Core/ModuleResult.swift` | *(verify Codable round-trip is tested)* |
| `Core/Finding.swift` | *(verify severity, location, Codable are tested)* |
| `Rules/*.swift` (18 rules) | `Rules/*Tests.swift` — one file per rule |
| `Reporters/HTMLReporter.swift` | `Reporters/HTMLReporterTests.swift` |
| `Reporters/MarkdownReporter.swift` | `Reporters/MarkdownReporterTests.swift` |
| `Reporters/JSONReporter.swift` | `Reporters/JSONReporterTests.swift` |

Use this shell snippet to find Rules without a corresponding test file:

```bash
for f in Sources/Swift6MigrationAnalyzerCore/Rules/*.swift; do
  base=$(basename "$f" .swift)
  test_file="Tests/Swift6MigrationAnalyzerTests/Rules/${base}Tests.swift"
  [ ! -f "$test_file" ] && echo "MISSING: $test_file"
done
```

### 2.2 Write the missing tests

For each gap found in 2.1, write tests following the patterns in `RuleTestHelpers.swift` and
`ReporterTestHelpers.swift`. Each test must:

- Use `@Test("descriptive sentence in plain English")` from the Swift Testing framework.
- Follow **Arrange → Act → Assert**.
- Include at least one **negative case** per rule (clean Swift 6 code must not be flagged).
- Not duplicate an existing test.

After adding tests, run `swift test`. The final count must be strictly higher than the baseline.

---

## 3 — Code Quality & Bug Review

### 3.1 Audit each Rule for correct severity

Open every file in `Sources/Swift6MigrationAnalyzerCore/Rules/`. For each rule verify:

- **`.error` severity** is used only for patterns that cause actual Swift 6 **compilation errors**:
  `GlobalMutableStateRule`, `NonisolatedUnsafeRule`, `UncheckedSendableRule`,
  `DispatchQueueRule` (all patterns: `.async`, `.sync`, manual creation),
  `ThreadRule` (`Thread.detachNewThread` / `Thread(block:)` only),
  `SynchronizationPrimitiveRule`, `DispatchGroupRule`, `TaskDetachedRule`,
  `CombineRule` (`.sink` and `assign(to:on:)` — `AnyCancellable` stays `.warning`).
- **`.warning` severity** is used for patterns that are **recommendations** but do not block
  compilation: `CompletionHandlerRule`, `ObservableObjectRule`, `PreconcurrencyRule`,
  `TimerRule`, `NotificationCenterRule`, `OperationQueueMainRule`, `MainActorMissingRule`,
  `CombineRule` (AnyCancellable only), `ThreadRule` (`isMainThread`/`main`/`current` only).
- Each finding message is **actionable**: it states the problem and hints at the fix.

Consult `FindingComplexity.weightTable` — the rationale string for each rule explicitly
states whether it is a compile error or a recommendation.

### 3.2 Review score computation

In `Core/FindingComplexity.swift`:

- Confirm `errorScore(for:)` calls `score(for:)` on the pre-filtered `.error` subset only.
- Verify the weight table is still aligned with the Swift 6 language spec.
  Adjust weights if Apple has changed how strictly a pattern is enforced.
- Confirm no production code path calls the legacy `score(for:)` (all callers should use
  `errorScore(for:)`).

### 3.3 Review Analyzer aggregate logic

In `Core/Analyzer.swift`:

- Confirm `buildStatus(score:findings:)` correctly sets `.warnings` tag when any finding has
  `.warning` or `.info` severity — even when the error score is 0.
- Confirm `computeAggregates` propagates the `.warnings` tag upward (a parent module must
  carry `.warnings` if any descendant has warning findings).
- Confirm `analyzeAsModule(file:)` uses `buildStatus` (not raw `score == 0 ? .migrated : .pendingMigration`).

### 3.4 Review reporters

In `HTMLReporter`, `MarkdownReporter`, `JSONReporter`:

- `projectStatus` must be derived from composite tags (error score + warning presence), not score alone.
- `migratedCount` / `migratedPercent` must count modules where `aggregateStatus.isMigrated == true`
  (this includes `Migrated · Warnings`).
- The HTML score gradient threshold must use the **actual 80th-percentile** of non-zero scores,
  not a hardcoded constant.
- The HTML module table rows must carry `data-depth`, `data-safe-id`, and `data-parent-id`
  attributes for the collapse/expand and hierarchy-sort JavaScript.

### 3.5 Compiler warning sweep

```bash
swift build 2>&1 | grep -E "warning:|note:"
```

Resolve every warning that is not intentional. Pay special attention to `Sendable`-conformance
warnings — the tool itself must be concurrency-clean under Swift 6 strict mode.

---

## 4 — Documentation Update

### 4.1 DocC inline comments

Add `///` doc comments to any public symbol that lacks one. Priority order:

1. `MigrationTag` — document each case and explain when each tag appears.
2. `MigrationStatus` — document the four valid tag combinations and the `badgesHTML` / `badgesMarkdown` helpers.
3. `FindingComplexity.errorScore(for:)` — explain why `.warning` findings are excluded.
4. `Analyzer.analyzeModules(in:fileScanner:maxDepth:)` — describe the two-pass algorithm (raw results → `computeAggregates`).
5. `Rule` protocol — specify which `.severity` values conforming types should use and why.

### 4.2 Update `AGENT_USAGE.md`

Review `AGENT_USAGE.md` against the current `CLI.swift` and verify:

- Every CLI flag is documented with its current default value and accepted inputs.
- The JSON output schema example reflects the current shape — especially:
  - `status` is now a **JSON array of tag strings** (e.g. `["Migrated", "Warnings"]`), not a single string.
  - `migratedModules` and `migratedPercent` fields are documented.
- Any new flags or behaviours introduced this week are added to the guide.

### 4.3 Update the README main screenshot

> **Image size reference:** The current screenshot in `README.md` is **1162 × 992 px**
> (`width="1162" height="992"`). Match this exact size when taking the new screenshot so the
> README layout stays consistent.

Generate a fresh HTML report:

```bash
swift run Swift6MigrationAnalyzer <path-to-sample-project> \
    --report html \
    --output /tmp/report.html

open /tmp/report.html
```

Take a screenshot at **1162 × 992 px** that clearly shows:

- **Header:** composite status badges side-by-side (e.g. `⏳ Pending Migration` + `⚠️ Warnings`
  as separate coloured pills).
- **Summary grid:** includes the green **Modules Migrated (X%)** card.
- **Module table:** depth stepper toolbar visible; at least one row of each badge type
  (green ✅ Migrated, amber ⚠️ Warnings, orange ⏳ Pending Migration); score gradient colours
  visible across multiple rows (green → yellow → red).
- **At least one collapsed parent row** with the `▶` toggle visible to demonstrate the
  hierarchy collapse feature.

Upload the image to GitHub (drag into a PR/issue comment box to obtain the CDN URL), then
replace the `<img>` tag in `README.md`:

```html
<img width="1162" height="992" alt="Swift 6 Migration Analyzer HTML Report" src="<new-cdn-url>" />
```

Commit the image change and README update together:

```
docs(readme): update screenshot to reflect current HTML report design
```

---

## 5 — Final Verification & Commit

```bash
swift build
swift test
```

Confirm:

- ✅ `swift build` — zero errors, zero new warnings.
- ✅ Test count ≥ baseline recorded in step 0.

Commit all changes produced during this audit cycle with a structured message:

```
chore(weekly-audit): YYYY-MM-DD maintenance pass

- Deps: swift-syntax X.Y.Z, argument-parser X.Y.Z (or "no changes")
- Tests: N tests (was M) — added coverage for <list of gaps fixed>
- Bugs: <describe any fixes, or "none found">
- Docs: updated AGENT_USAGE.md / README screenshot / DocC comments
```

Push to `main`:

```bash
git push
```

---

## Appendix — Quick Reference Commands

### Full test suite
```bash
swift test
```

### Generate all report formats
```bash
swift run Swift6MigrationAnalyzer <path> --report html     --output report.html
swift run Swift6MigrationAnalyzer <path> --report markdown --output report.md
swift run Swift6MigrationAnalyzer <path> --report json     --output report.json
```

### Show resolved dependency versions
```bash
cat Package.resolved | grep -A2 '"identity"'
```

### List all registered rule names
```bash
grep -r 'public var name' Sources/Swift6MigrationAnalyzerCore/Rules/
```

### Count tests per suite
```bash
swift test 2>&1 | grep "Suite.*passed"
```

### Find Rules without a test file
```bash
for f in Sources/Swift6MigrationAnalyzerCore/Rules/*.swift; do
  base=$(basename "$f" .swift)
  test_file="Tests/Swift6MigrationAnalyzerTests/Rules/${base}Tests.swift"
  [ ! -f "$test_file" ] && echo "MISSING: $test_file"
done
```

### Check for compiler warnings
```bash
swift build 2>&1 | grep -E "warning:|note:"
```
