# LegacyApp — Swift 6 Migration Demo Workspace

This workspace is a **demo project** designed to showcase the full capabilities of the `Swift 6 Migration Analyzer` tool. It simulates a realistic multi-package iOS app at various stages of Swift 6 migration.

## Structure

```
LegacyApp/
├── AppShell/          ✅ Fully migrated — actors, @MainActor, async/await
│   ├── AppEntry/      ✅ App lifecycle with structured concurrency
│   └── AppCoordinator/✅ Actor-based routing & feature flags
├── CoreFeatures/      ⏳ Pending migration — ObservableObject, DispatchQueue, callbacks
│   ├── Authentication/⏳ @unchecked Sendable, NSLock, completion handlers
│   ├── Dashboard/     ⏳ ObservableObject, Timer, DispatchGroup, Combine
│   └── Settings/      ⏳ GlobalMutableState, NotificationCenter, @Published
├── Infrastructure/    ⏳ Pending — severe concurrency issues
│   ├── Networking/    ⏳ Thread, DispatchGroup, nonisolated(unsafe), UncheckedSendable
│   ├── Persistence/   ⏳ DispatchSemaphore, NSLock, force-try, force-unwrap
│   └── Logging/       ⏳ OperationQueue.main, @preconcurrency, Task.detached
└── SharedKit/         ✅ Fully migrated — Sendable models, actor repositories
    ├── DesignSystem/  ✅ @MainActor UIKit components & design tokens
    ├── Extensions/    ✅ Pure Swift extensions
    └── Models/        ✅ Sendable structs & actor-based repositories
```

## Running the analyzer

From the `Swift6-migration` repo root:

```bash
# HTML report
.build/release/Swift6MigrationAnalyzer LegacyApp \
  --report html \
  --output /tmp/legacyapp-report.html

open /tmp/legacyapp-report.html
```

```bash
# JSON report for programmatic processing
.build/release/Swift6MigrationAnalyzer LegacyApp \
  --report json \
  --output /tmp/legacyapp-report.json
```

## What this demo exercises

| Capability | Demonstrated by |
|---|---|
| Multi-package workspace detection (Strategy 1) | 4 sub-packages each with `Package.swift` |
| SPM target detection (Strategy 2) | Each package has 2–3 targets in `Sources/` |
| Depth scanning (levels 1 → 3) | workspace → package → target |
| Migrated modules (score 0.0) | `AppShell/*`, `SharedKit/*` |
| Pending modules with varied scores | `CoreFeatures/*`, `Infrastructure/*` |
| All 16 built-in rules | Distributed across modules |
