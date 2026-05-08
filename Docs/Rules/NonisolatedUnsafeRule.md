# NonisolatedUnsafeRule

**Severity:** 🔴 error  
**Complexity Weight:** 0.9  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Stored property declarations marked with `nonisolated(unsafe)`. This modifier is the property-level equivalent of `@unchecked Sendable` — the compiler disables all concurrency checking for that property and trusts the developer to ensure safety manually.

---

## Why It Matters

`nonisolated(unsafe)` is a temporary escape hatch introduced in Swift 6 to silence migration errors. It does **not** make the code safe — it just silences the compiler. Every use must be audited and eventually replaced with a proper concurrency-safe solution.

---

## ❌ Wrong

```swift
class NetworkManager {
    nonisolated(unsafe) var session: URLSession = .shared
    nonisolated(unsafe) static var shared = NetworkManager()
}

// File scope
nonisolated(unsafe) var globalRegistry: [String: AnyObject] = [:]
```

---

## ✅ Correct

**Option A — Isolate with an actor**:
```swift
actor NetworkManager {
    var session: URLSession = .shared
    static let shared = NetworkManager()
}
```

**Option B — Use `@MainActor` for UI-bound state**:
```swift
@MainActor
class NetworkManager {
    var session: URLSession = .shared
}
```

**Option C — Use `Mutex` from the `Synchronization` module** (Swift 6, no actor overhead):
```swift
import Synchronization

let globalRegistry = Mutex<[String: AnyObject]>([:])

// Access:
globalRegistry.withLock { $0["key"] = value }
```

**Option D — Make it a `let` constant**:
```swift
let session: URLSession = .shared  // immutable — always safe
```

---

## References

- [SE-0412 – Strict concurrency for global variables](https://github.com/apple/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md)
- [Swift 6 Migration Guide](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/)
