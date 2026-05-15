# MainActorRunRule

**Severity:** 🔴 error  
**Complexity Weight:** 0.7  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

`await MainActor.run { ... self ... }` calls made from **non-isolated, non-Sendable classes**.

Specifically, the rule fires when all of the following are true:

1. The `await MainActor.run { }` call appears inside a class body.
2. The class does **not** have `@MainActor` annotation.
3. The class is **not** declared as an `actor`.
4. The closure captures `self`.

---

## Why It Matters

In Swift 6 strict concurrency, `self` of a non-Sendable class cannot be sent across actor boundaries. Calling `await MainActor.run { }` from a non-isolated async context crosses the isolation boundary into `@MainActor`. If `self` is captured in that closure, the compiler rejects this with:

> **error: Sending 'self' risks causing data races**

This is a **compile error under `.swiftLanguageMode(.v6)`**.

---

## ❌ Wrong

```swift
class NetworkManager {
    var result: String = ""

    func load() async {
        let data = await fetchData()
        await MainActor.run {
            self.result = data   // ← Swift 6 error: 'self' is non-Sendable
        }
    }
}
```

---

## ✅ Correct

**Option A — Annotate the class with `@MainActor`** (simplest, for UI-facing types):

```swift
@MainActor
class NetworkManager {
    var result: String = ""

    func load() async {
        let data = await fetchData()
        self.result = data   // ✅ always on MainActor
    }
}
```

**Option B — Conform to `Sendable`** (for types that are genuinely safe to share):

```swift
final class NetworkManager: Sendable {
    // All stored properties must be constants or actor-isolated
    let result: String

    func load() async {
        let data = await fetchData()
        await MainActor.run {
            // If result were mutable, use @MainActor on the property or enclosing type
        }
    }
}
```

**Option C — Pass only Sendable value types into the closure**:

```swift
class NetworkManager {
    @MainActor var result: String = ""

    func load() async {
        let data = await fetchData()    // data: String (Sendable)
        await MainActor.run { [data] in
            // Only data (a captured value copy) is sent — not self
        }
    }
}
```

---

## References

- [SE-0313 – Improved control over actor isolation](https://github.com/apple/swift-evolution/blob/main/proposals/0313-actor-isolation-control.md)
- [Swift Concurrency — Sendable and @Sendable closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types)
