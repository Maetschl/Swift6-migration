# OperationQueueMainRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.7  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Calls to `OperationQueue.main.addOperation { }` or `OperationQueue.main.addOperation(BlockOperation { })`.

---

## Why It Matters

`OperationQueue.main` is the Objective-C-era equivalent of `DispatchQueue.main`. It schedules work on the main thread via `RunLoop`, bypassing Swift 6 actor isolation. Closures enqueued this way are not tracked by the actor system and can silently capture actor-isolated state across concurrency boundaries.

---

## ❌ Wrong

```swift
func reloadUI() {
    OperationQueue.main.addOperation {
        self.tableView.reloadData()    // ← not actor-isolated
        self.titleLabel.text = "Done"
    }
}

OperationQueue.main.addOperation(BlockOperation {
    self.updateBadge()                 // ← Swift 6 isolation error
})
```

---

## ✅ Correct

**Option A — Annotate the class with `@MainActor`**:
```swift
@MainActor
class DashboardViewController: UIViewController {
    func reloadUI() {
        tableView.reloadData()
        titleLabel.text = "Done"
    }
}
```

**Option B — Use `Task { @MainActor in ... }`** (from a non-isolated context):
```swift
func reloadUI() {
    Task { @MainActor in
        self.tableView.reloadData()
        self.titleLabel.text = "Done"
    }
}
```

---

## References

- [SE-0316 – Global actors](https://github.com/apple/swift-evolution/blob/main/proposals/0316-global-actors.md)
