# SynchronizationPrimitiveRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.8  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Declarations of manual synchronization primitives:
`NSLock`, `NSRecursiveLock`, `NSCondition`, `NSConditionLock`,
`DispatchSemaphore`, `pthread_mutex_t`, `os_unfair_lock`,
`os_unfair_lock_t`, `OSAllocatedUnfairLock`.

---

## Why It Matters

Manual locking is error-prone (deadlocks, forgotten unlocks, wrong lock order) and invisible to the Swift 6 concurrency model. Swift actors provide the same mutual exclusion guarantee with compile-time enforcement and no risk of forgetting to lock/unlock.

---

## ❌ Wrong

```swift
class DataStore {
    private let lock = NSLock()
    private var cache: [String: Data] = [:]

    func set(_ data: Data, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = data
    }

    func get(_ key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }
}
```

---

## ✅ Correct

**Option A — Convert to an actor** (preferred for Swift 6):
```swift
actor DataStore {
    private var cache: [String: Data] = [:]

    func set(_ data: Data, for key: String) {
        cache[key] = data
    }

    func get(_ key: String) -> Data? {
        cache[key]
    }
}
```

**Option B — Use `Mutex` from `Synchronization`** (synchronous access, no `await` needed):
```swift
import Synchronization

final class DataStore: Sendable {
    private let cache = Mutex<[String: Data]>([:])

    func set(_ data: Data, for key: String) {
        cache.withLock { $0[key] = data }
    }

    func get(_ key: String) -> Data? {
        cache.withLock { $0[key] }
    }
}
```

---

## References

- [SE-0433 – Mutex](https://github.com/apple/swift-evolution/blob/main/proposals/0433-mutex.md)
- [Swift 6 Migration Guide](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/)
