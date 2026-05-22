# ActorReentrancyRule

## What it detects
`async` methods inside `actor` declarations that `await` external (non-self) calls, creating potential reentrancy windows.

## Why it matters in Swift 6
Actors in Swift provide mutual exclusion, but they are **reentrant** — while an actor method is suspended at an `await` point, other tasks can call into the same actor and mutate its state. When the first task resumes, any state it read before the suspension may be stale.

## ❌ Wrong code
```swift
actor Cache {
    var items: [String: Any] = [:]

    func refresh() async {
        let fresh = await networkService.fetchItems() // suspension point
        items = fresh  // ⚠️ items may have been mutated by another caller while suspended
    }
}
```

## ✅ Correct code
```swift
actor Cache {
    var items: [String: Any] = [:]

    func refresh() async {
        let fresh = await networkService.fetchItems()
        // Check invariants after resuming — guard against concurrent modification
        guard items.isEmpty else { return }  // another task may have already refreshed
        items = fresh
    }
}
```

Or restructure so no mutable state is accessed after the suspension point.
