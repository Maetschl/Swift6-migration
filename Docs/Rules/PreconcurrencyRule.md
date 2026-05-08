# PreconcurrencyRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.4  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

- `@preconcurrency import SomeModule` declarations
- `@preconcurrency` on protocol conformances in inheritance clauses

---

## Why It Matters

`@preconcurrency` is a migration bridge that silences Swift 6 `Sendable` and isolation warnings coming from modules that haven't adopted concurrency yet. Every `@preconcurrency` annotation is a **suppressed error** — real concurrency problems that will exist at runtime even though the compiler stays silent.

---

## ❌ Wrong

```swift
@preconcurrency import LegacyAnalytics   // ← suppresses Sendable warnings from module
@preconcurrency import OldNetworking     // ← hides isolation issues

// Protocol conformance suppression
class Tracker: @preconcurrency AnalyticsDelegate {
    func track(_ event: LegacyEvent) {
        // LegacyEvent may not be Sendable — compiler won't tell you
    }
}
```

---

## ✅ Correct

**Option A — Add `Sendable` conformance to the offending type**:
```swift
// Retroactive conformance in your own module
extension LegacyEvent: @retroactive Sendable {}

import LegacyAnalytics  // no @preconcurrency needed
```

**Option B — Wrap the non-Sendable type in a Sendable struct**:
```swift
struct SafeEvent: Sendable {
    let name: String
    let timestamp: Date
    // copy only Sendable fields from LegacyEvent
}

class Tracker: AnalyticsDelegate {
    func track(_ event: LegacyEvent) {
        let safe = SafeEvent(name: event.name, timestamp: event.timestamp)
        // use safe instead of event across concurrency boundaries
    }
}
```

**Option C — Isolate the conformance to `@MainActor`**:
```swift
@MainActor
class Tracker: AnalyticsDelegate {
    func track(_ event: LegacyEvent) {
        // Always on MainActor — isolation is explicit and compiler-enforced
    }
}
```

---

## References

- [SE-0337 – Incremental migration to concurrency checking](https://github.com/apple/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md)
