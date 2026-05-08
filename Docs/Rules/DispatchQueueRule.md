# DispatchQueueRule

**Severity:** ⚠️ warning (`.async`) / 🔴 error (`.sync`)  
**Complexity Weight:** 0.7  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

- `DispatchQueue.main.async { }` — warning
- `DispatchQueue.main.asyncAfter(deadline:execute:)` — warning
- `DispatchQueue.global().async { }` — warning
- `DispatchQueue.*.sync { }` — error (blocks calling thread)
- `DispatchQueue(label:)` custom queue creation — warning

---

## Why It Matters

`DispatchQueue` closures run outside the actor isolation model. A `.async` closure that captures `self` from a `@MainActor` type generates *"Sending 'self' risks causing data races"* in Swift 6. `.sync` is worse — it blocks the calling thread and can deadlock when called from the main thread.

---

## ❌ Wrong

```swift
// Dispatching to main from a background context
func fetchComplete(data: Data) {
    DispatchQueue.main.async {
        self.tableView.reloadData()  // ← Swift 6 isolation error
    }
}

// Blocking sync dispatch
func readConfig() -> Config {
    var config: Config!
    DispatchQueue.main.sync {        // ← deadlock risk + Swift 6 error
        config = self.currentConfig
    }
    return config
}

// Custom serial queue instead of actor
let queue = DispatchQueue(label: "com.app.serial")
queue.async {
    self.process()                   // ← not actor-isolated
}
```

---

## ✅ Correct

**Option A — Annotate type with `@MainActor`** (best for view controllers/views):
```swift
@MainActor
class FeedViewController: UIViewController {
    func fetchComplete(data: Data) {
        tableView.reloadData()  // already on MainActor, no dispatch needed
    }
}
```

**Option B — Use `await MainActor.run { }`** (when caller is not `@MainActor`):
```swift
func fetchComplete(data: Data) async {
    await MainActor.run {
        tableView.reloadData()
    }
}
```

**Option C — Replace custom serial queue with an actor**:
```swift
actor Processor {
    func process() { /* runs isolated */ }
}

let processor = Processor()
await processor.process()
```

**Option D — Replace asyncAfter with `Task.sleep`**:
```swift
Task { @MainActor in
    try await Task.sleep(for: .seconds(2))
    self.hideBanner()
}
```

---

## References

- [SE-0316 – Global actors](https://github.com/apple/swift-evolution/blob/main/proposals/0316-global-actors.md)
- [Swift 6 Migration Guide – Dispatch](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/)
