# AsyncSequenceRule

## What it detects
Usage of Combine's `PassthroughSubject` and `CurrentValueSubject` — imperative event sources that can be replaced with Swift 6 `AsyncStream` / `AsyncThrowingStream`.

## Why it matters in Swift 6
Combine subjects require manual subscriber management and don't integrate with Swift's structured concurrency. `AsyncStream` provides a first-class `AsyncSequence` that works naturally with `for await` loops, task cancellation, and actor isolation.

## ❌ Wrong code
```swift
let subject = PassthroughSubject<Int, Never>()
subject.send(42)
```

## ✅ Correct code
```swift
let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
continuation.yield(42)

for await value in stream {
    process(value)
}
```
