# CombineRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.6  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

- `.sink { }` subscriber closures
- `assign(to:on:)` publisher subscriptions
- `AnyCancellable` stored property declarations

---

## Why It Matters

Combine's threading model predates Swift 6. `.sink` closures execute on whatever thread/scheduler the upstream publisher delivers on — there is no actor-isolation guarantee. `assign(to:on:)` sends values to `self` across a potential concurrency boundary. In Swift 6, these patterns produce *"Sending 'self' risks causing data races"* errors.

---

## ❌ Wrong

```swift
class FeedViewModel: ObservableObject {
    @Published var items: [Item] = []
    var cancellables = Set<AnyCancellable>()

    func load() {
        service.fetchItems()
            .sink { [weak self] items in   // ← may run on arbitrary thread
                self?.items = items         // ← Swift 6 isolation error
            }
            .store(in: &cancellables)
    }
}
```

---

## ✅ Correct

**Option A — Use `.values` async sequence with `for await`**:
```swift
@MainActor
class FeedViewModel {
    var items: [Item] = []

    func load() async {
        for await items in service.fetchItems().values {
            self.items = items  // safe — we're @MainActor
        }
    }
}
```

**Option B — Use `@Observable` + async task**:
```swift
import Observation

@Observable
@MainActor
class FeedViewModel {
    var items: [Item] = []

    func load() async throws {
        items = try await service.fetchItems()
    }
}
```

**Option C — Receive on `MainActor` explicitly** (when keeping Combine temporarily):
```swift
service.fetchItems()
    .receive(on: RunLoop.main)
    .sink { @MainActor [weak self] items in
        self?.items = items
    }
    .store(in: &cancellables)
```

---

## References

- [SE-0395 – Observation](https://github.com/apple/swift-evolution/blob/main/proposals/0395-observability.md)
- [SE-0314 – AsyncStream](https://github.com/apple/swift-evolution/blob/main/proposals/0314-async-stream.md)
