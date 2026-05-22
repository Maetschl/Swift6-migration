# WithUnsafeCurrentTaskRule

## What it detects
Usage of the deprecated `withUnsafeCurrentTask { }` and `Task.current` APIs.

## Why it matters in Swift 6
These APIs were deprecated in Swift 5.9 and removed from the recommended concurrency model. `withUnsafeCurrentTask` exposes the underlying task handle without ownership guarantees. `Task.current` encourages imperative cancellation checks that fight structured concurrency.

## ❌ Wrong code
```swift
withUnsafeCurrentTask { task in
    task?.cancel()
}

let t = Task.current
```

## ✅ Correct code
```swift
// Cancellation propagation
try await withTaskCancellationHandler {
    await doWork()
} onCancel: {
    cleanup()
}

// Cancellation check inside async code
try Task.checkCancellation()
```
