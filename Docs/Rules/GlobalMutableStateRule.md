# GlobalMutableStateRule

**Severity:** 🔴 error  
**Complexity Weight:** 0.9  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Top-level (file-scope) `var` declarations that are not isolated to an actor or annotated with `@MainActor`. In Swift 6 strict concurrency mode, these are **compile errors**:

> *"Var 'X' is not concurrency-safe because it is non-isolated global shared mutable state."*

---

## Why It Matters

Global mutable variables are accessible from any thread simultaneously. Swift 6 enforces that all shared mutable state must be protected by actor isolation. A plain global `var` has no isolation domain, so any concurrent access is a data race.

---

## ❌ Wrong

```swift
// Global var — not safe in Swift 6
var currentUser: User?
var appConfig = AppConfiguration()
var requestCount = 0
```

---

## ✅ Correct

**Option A — Annotate with `@MainActor`** (best for UI-related state):
```swift
@MainActor var currentUser: User?
@MainActor var appConfig = AppConfiguration()
```

**Option B — Wrap in an actor**:
```swift
actor AppState {
    var currentUser: User?
    var requestCount = 0
}

let appState = AppState()
```

**Option C — Make it a `let` constant** (if value never changes):
```swift
let appConfig = AppConfiguration()
```

**Option D — Use `nonisolated(unsafe)` only as last resort** (requires manual audit):
```swift
// Only if you can prove all accesses are serialized externally
nonisolated(unsafe) var legacySharedCache: [String: Any] = [:]
```

---

## References

- [SE-0412 – Strict concurrency for global variables](https://github.com/apple/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md)
- [Swift 6 Migration Guide](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/)
