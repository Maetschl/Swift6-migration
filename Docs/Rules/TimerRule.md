# TimerRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.5  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

- `Timer.scheduledTimer(withTimeInterval:repeats:block:)`
- `Timer.scheduledTimer(timeInterval:target:selector:userInfo:repeats:)`
- `Timer(timeInterval:repeats:block:)` initializer

---

## Why It Matters

`Timer` fires on the `RunLoop` of the thread it was scheduled on. The callback closure is not actor-isolated, so any mutation of `@MainActor` state inside the closure is a Swift 6 isolation violation. Additionally, `target/selector`-based timers retain the target strongly, causing memory leaks.

---

## ❌ Wrong

```swift
@MainActor
class ClockViewModel {
    var time = ""
    var timer: Timer?

    func startClock() {
        // Closure fires on RunLoop thread — not actor-isolated
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.time = Date().formatted()  // ← Swift 6 isolation error
        }
    }
}
```

---

## ✅ Correct

**Option A — `Task` + `Task.sleep` for a repeating timer**:
```swift
@MainActor
class ClockViewModel {
    var time = ""
    private var clockTask: Task<Void, Never>?

    func startClock() {
        clockTask = Task {
            while !Task.isCancelled {
                time = Date().formatted()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopClock() {
        clockTask?.cancel()
    }
}
```

**Option B — `AsyncStream`-based clock** (reusable utility):
```swift
func makeClock(interval: Duration) -> AsyncStream<Date> {
    AsyncStream { continuation in
        let task = Task {
            while !Task.isCancelled {
                continuation.yield(Date())
                try? await Task.sleep(for: interval)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

// Usage inside @MainActor context:
for await tick in makeClock(interval: .seconds(1)) {
    time = tick.formatted()
}
```

---

## References

- [SE-0314 – AsyncStream](https://github.com/apple/swift-evolution/blob/main/proposals/0314-async-stream.md)
- [SE-0329 – Clock, Instant, Duration](https://github.com/apple/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md)
