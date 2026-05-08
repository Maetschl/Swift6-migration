# DispatchGroupRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.6  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

`DispatchGroup()` declarations and usages including `group.enter()`, `group.leave()`, `group.notify(queue:execute:)`, and `group.wait()`.

---

## Why It Matters

`DispatchGroup` coordinates work across arbitrary threads with no awareness of actor isolation. `group.wait()` blocks the calling thread (deadlock risk). `group.notify` schedules the completion closure on a `DispatchQueue`, not an actor. Swift 6 offers structured replacements that are safer and more readable.

---

## ❌ Wrong

```swift
func loadAll() {
    let group = DispatchGroup()

    group.enter()
    networkService.fetchUser { user in
        self.user = user        // ← isolation violation
        group.leave()
    }

    group.enter()
    networkService.fetchPosts { posts in
        self.posts = posts      // ← isolation violation
        group.leave()
    }

    group.notify(queue: .main) {
        self.tableView.reloadData()
    }
}
```

---

## ✅ Correct

**Option A — Use `async let` for parallel work** (fixed number of tasks):
```swift
@MainActor
func loadAll() async throws {
    async let user  = networkService.fetchUser()
    async let posts = networkService.fetchPosts()
    self.user  = try await user
    self.posts = try await posts
    tableView.reloadData()
}
```

**Option B — Use `withTaskGroup` for dynamic parallel work**:
```swift
@MainActor
func loadAll() async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await self.loadUser() }
        group.addTask { try await self.loadPosts() }
        try await group.waitForAll()
    }
    tableView.reloadData()
}
```

---

## References

- [SE-0304 – Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
