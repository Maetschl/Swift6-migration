# NotificationCenterRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.4  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

- `NotificationCenter.default.addObserver(forName:object:queue:using:)` — closure-based observer
- `NotificationCenter.default.addObserver(_:selector:name:object:)` — selector-based observer
- `NotificationCenter.default.post(name:object:userInfo:)`

---

## Why It Matters

`NotificationCenter` delivers notifications on the thread that posts them (unless an explicit `queue:` is provided). In Swift 6, closures that capture `self` from a `@MainActor` type will produce:

> *"Sending 'self' risks causing data races"*

…because the closure may fire on a background thread. Similarly, calling `.post` from a background context can violate the observer's actor isolation.

---

## ❌ Wrong

```swift
@MainActor
class FeedViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // queue: nil means "fire on posting thread" — could be background
        NotificationCenter.default.addObserver(
            forName: .dataDidRefresh,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.tableView.reloadData()  // ← Swift 6 isolation error
        }
    }
}

// Posting from a background context
Task.detached {
    NotificationCenter.default.post(name: .dataDidRefresh, object: nil)
    // ← receiver may be @MainActor isolated
}
```

---

## ✅ Correct

**Option A — Use `NotificationCenter.notifications` async sequence** (preferred):
```swift
@MainActor
class FeedViewController: UIViewController {
    private var observationTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        observationTask = Task {
            for await _ in NotificationCenter.default.notifications(named: .dataDidRefresh) {
                tableView.reloadData()  // safe — Task inherits @MainActor context
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        observationTask?.cancel()
    }
}
```

**Option B — Explicitly annotate the closure with `@MainActor`** (quick fix):
```swift
NotificationCenter.default.addObserver(
    forName: .dataDidRefresh,
    object: nil,
    queue: .main
) { @MainActor [weak self] _ in
    self?.tableView.reloadData()
}
```

**Option C — Replace with actor-based communication** (for app-internal events):
```swift
// Use an AsyncStream or actor property instead of NotificationCenter
actor DataRefreshCoordinator {
    private var continuations: [AsyncStream<Void>.Continuation] = []

    var refreshStream: AsyncStream<Void> {
        AsyncStream { continuation in
            continuations.append(continuation)
        }
    }

    func notifyRefresh() {
        continuations.forEach { $0.yield(()) }
    }
}
```

---

## References

- [SE-0314 – AsyncStream](https://github.com/apple/swift-evolution/blob/main/proposals/0314-async-stream.md)
