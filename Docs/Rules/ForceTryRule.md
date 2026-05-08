# ForceTryRule

**Severity:** 🔴 error  
**Complexity Weight:** 0.8  
**Category:** Code Quality (opt-in via `--include-quality-rules`)

---

## What It Detects

Force-try expressions: `try! expression`.

---

## Why It Matters

`try!` crashes the process when the expression throws. In concurrent code, a crash on a background thread or inside an actor terminates the entire process with no recovery path and no meaningful error handling. Swift 6 makes `async throws` so ergonomic that there is no reason to use `try!` in new code.

---

## ❌ Wrong

```swift
// Any of these crash the app if the operation throws
let data     = try! Data(contentsOf: fileURL)
let user     = try! JSONDecoder().decode(User.self, from: data)
let regex    = try! NSRegularExpression(pattern: "\\d+")
let keychain = try! Keychain.load(key: "token")

// Especially dangerous in async context — crashes the whole process
func loadConfig() async {
    config = try! await networkService.fetchConfig()
}
```

---

## ✅ Correct

**`do/catch` — handle the error explicitly:**
```swift
do {
    let data = try Data(contentsOf: fileURL)
    let user = try JSONDecoder().decode(User.self, from: data)
    display(user)
} catch DecodingError.keyNotFound(let key, _) {
    logger.error("Missing key: \(key)")
    showFallbackUI()
} catch {
    logger.error("Load failed: \(error)")
    showErrorState()
}
```

**`try?` with nil coalescing — when failure has a sensible default:**
```swift
let cachedUser = try? JSONDecoder().decode(User.self, from: data)
let name = cachedUser?.name ?? "Guest"
```

**`async throws` propagation — let the caller decide:**
```swift
func loadConfig() async throws -> Config {
    let data = try await URLSession.shared.data(from: configURL).0
    return try JSONDecoder().decode(Config.self, from: data)
}

// Caller handles it:
do {
    config = try await loadConfig()
} catch {
    config = .default
    logger.error("Config load failed, using defaults: \(error)")
}
```

**Compile-time safe regex (Swift 5.7+):**
```swift
// Regex literals are validated at compile time — no try needed
let regex = /\d+/
```

---

## References

- [Swift Book – Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
- [SE-0296 – Async/await](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
