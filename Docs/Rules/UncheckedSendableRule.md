# UncheckedSendableRule

**Severity:** 🔴 error  
**Complexity Weight:** 1.0  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Types that conform to `@unchecked Sendable`. This tells the compiler "trust me, this type is safe to send across concurrency boundaries" without any verification. It is the highest-risk escape hatch in the Swift 6 concurrency model.

---

## Why It Matters

`Sendable` conformance is the compiler's guarantee that a value is safe to share across actor boundaries. `@unchecked Sendable` bypasses that guarantee entirely. Any data race present in the type is invisible to the compiler but can cause crashes or corrupted state at runtime.

---

## ❌ Wrong

```swift
// Class with mutable state — NOT actually safe
class UserCache: @unchecked Sendable {
    var users: [String: User] = [:]  // ← data race waiting to happen
}

// Struct wrapping a non-Sendable reference type
struct Wrapper: @unchecked Sendable {
    var delegate: NSObject           // ← NSObject is not Sendable
}
```

---

## ✅ Correct

**Option A — Convert to an actor** (mutable shared state):
```swift
actor UserCache {
    private var users: [String: User] = [:]

    func user(for id: String) -> User? { users[id] }
    func store(_ user: User, for id: String) { users[id] = user }
}
```

**Option B — Use a value type** (structs with `Sendable` stored properties are implicitly `Sendable`):
```swift
struct UserCache: Sendable {
    let users: [String: User]  // immutable — always safe
}
```

**Option C — Use `Mutex` for lock-protected mutable state**:
```swift
import Synchronization

final class UserCache: Sendable {
    private let users = Mutex<[String: User]>([:])

    func user(for id: String) -> User? {
        users.withLock { $0[id] }
    }

    func store(_ user: User, for id: String) {
        users.withLock { $0[id] = user }
    }
}
```

---

## References

- [SE-0302 – Sendable and @Sendable closures](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
