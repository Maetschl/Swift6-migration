# TaskDetachedRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.6  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Calls to `Task.detached { }` and `Task.detached(priority:operation:)`.

---

## Why It Matters

`Task.detached` creates a task with **no actor context** — it does not inherit the actor isolation of the surrounding scope. Any access to actor-isolated state from inside a detached task requires an explicit `await` hop, which is easy to miss. In Swift 6, missing that hop is a compile error.

`Task { }` (non-detached) inherits the actor context of its creation site, which is almost always what you want.

---

## ❌ Wrong

```swift
@MainActor
class ViewModel {
    var title = ""

    func refresh() {
        Task.detached {               // ← loses @MainActor context
            let result = await api.fetch()
            self.title = result       // ← Swift 6 error: must await on MainActor
        }
    }
}
```

---

## ✅ Correct

**Option A — Use `Task { }` to inherit actor context** (most common fix):
```swift
@MainActor
class ViewModel {
    var title = ""

    func refresh() {
        Task {                        // inherits @MainActor automatically
            let result = await api.fetch()
            self.title = result       // ✅ safe
        }
    }
}
```

**Option B — Use `Task.detached` intentionally with explicit re-isolation**:
```swift
// Use only when you explicitly DO NOT want to inherit actor context
Task.detached(priority: .background) {
    let processed = await heavyProcessing(data)
    await MainActor.run { self.result = processed }
}
```

---

## References

- [SE-0304 – Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
