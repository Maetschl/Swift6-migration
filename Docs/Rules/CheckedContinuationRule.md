# CheckedContinuationRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.5  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Calls to `withUnsafeContinuation` and `withUnsafeThrowingContinuation`.

---

## Why It Matters

Both `withUnsafeContinuation` and `withUnsafeThrowingContinuation` are "unsafe" because they skip the **resume-count validation** that Swift's structured concurrency relies on. If the continuation is resumed zero times, the task hangs forever. If it is resumed more than once, the runtime state is silently corrupted.

`withCheckedContinuation` and `withCheckedThrowingContinuation` add a runtime check:

- **In debug builds** — crashes immediately with a clear diagnostic when resumed incorrectly, making bugs easy to find.
- **In release builds** — the check is stripped, so there is no performance overhead in production.

In Swift 6, this is not a compile error, but the checked variants are the clearly-preferred API. Using the unsafe variants is typically a sign that the code was written before the checked alternatives existed, and should be updated.

---

## ❌ Wrong

```swift
func loadUser(id: String) async -> User {
    await withUnsafeContinuation { continuation in
        legacyDataLayer.fetchUser(id: id) { user in
            continuation.resume(returning: user)
        }
    }
}
```

---

## ✅ Correct

**Use `withCheckedContinuation` (non-throwing):**

```swift
func loadUser(id: String) async -> User {
    await withCheckedContinuation { continuation in
        legacyDataLayer.fetchUser(id: id) { user in
            continuation.resume(returning: user)
        }
    }
}
```

**Use `withCheckedThrowingContinuation` (throwing):**

```swift
func loadUser(id: String) async throws -> User {
    try await withCheckedThrowingContinuation { continuation in
        legacyDataLayer.fetchUser(id: id) { result in
            continuation.resume(with: result)
        }
    }
}
```

---

## Migration Path

1. Replace `withUnsafeContinuation` → `withCheckedContinuation`
2. Replace `withUnsafeThrowingContinuation` → `withCheckedThrowingContinuation`
3. The closure signature and `resume` call-sites are **identical** — this is a pure name substitution.
4. Run the app in debug mode and confirm no "continuation resumed multiple times" or "continuation leaked" diagnostics appear.

---

## References

- [SE-0300 – Continuations for interfacing async tasks with synchronous code](https://github.com/apple/swift-evolution/blob/main/proposals/0300-continuation.md)
- [Swift Concurrency — Continuations (apple docs)](https://developer.apple.com/documentation/swift/withcheckedcontinuation(_:))
