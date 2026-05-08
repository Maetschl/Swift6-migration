# ThreadRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.7  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Direct use of the `Thread` class:
- `Thread.detachNewThread { }` / `Thread(block:)` — creates untracked threads
- `Thread.isMainThread` — thread-level guard, unreliable with actors
- `Thread.main` / `Thread.current` — thread identity checks

---

## Why It Matters

`Thread` operates below Swift 6's actor isolation model. `Thread.isMainThread` is especially dangerous — a function can be `@MainActor`-isolated yet still called from a background `Thread`, producing a false-positive check. Only `MainActor.assertIsolated()` gives a compiler-backed guarantee.

---

## ❌ Wrong

```swift
// Creating untracked background threads
Thread.detachNewThread {
    self.processData()  // ← no actor context, isolation unknown
}

// Thread-based UI guard (unreliable with actors)
func updateUI() {
    guard Thread.isMainThread else {
        DispatchQueue.main.async { self.updateUI() }
        return
    }
    label.text = "Done"  // ← still not actor-safe in Swift 6
}

// Manual thread init
let t = Thread { self.heavyWork() }
t.start()
```

---

## ✅ Correct

**Option A — Use a structured `Task`** (background work):
```swift
Task {
    await processData()
}
```

**Option B — Annotate with `@MainActor`** (UI updates):
```swift
@MainActor
func updateUI() {
    label.text = "Done"  // compiler enforces main-thread isolation
}

// Called from any context:
Task { await updateUI() }
```

**Option C — Assert isolation instead of checking thread**:
```swift
@MainActor
func updateUI() {
    MainActor.assertIsolated()  // runtime crash if not on MainActor — intentional guard
    label.text = "Done"
}
```

**Option D — Explicit priority background task**:
```swift
Task(priority: .background) {
    await heavyWork()
}
```

---

## References

- [Swift Concurrency – Tasks](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [SE-0316 – Global actors](https://github.com/apple/swift-evolution/blob/main/proposals/0316-global-actors.md)
