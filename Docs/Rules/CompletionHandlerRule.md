# CompletionHandlerRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.5  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Function parameters named `completion`, `handler`, or `callback` that are typed as `@escaping` closures.

---

## Why It Matters

Completion-handler-based APIs are the pre-`async/await` pattern for asynchronous work. In Swift 6, `@escaping` closures that capture actor-isolated `self` generate isolation errors because the closure can be called from any thread. Migrating to `async/await` removes the `@escaping` closure entirely, eliminating the source of the isolation violation.

---

## ❌ Wrong

```swift
// Declaration
func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
    URLSession.shared.dataTask(with: makeURL(id)) { data, _, error in
        if let error {
            completion(.failure(error))
            return
        }
        completion(.success(try! decode(data!)))
    }.resume()
}

// Call site — manual thread management required
fetchUser(id: "42") { result in
    DispatchQueue.main.async {         // ← extra hop needed
        switch result {
        case .success(let user): self.display(user)
        case .failure(let error): self.showError(error)
        }
    }
}
```

---

## ✅ Correct

```swift
// Declaration — clean async throws
func fetchUser(id: String) async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: makeURL(id))
    return try JSONDecoder().decode(User.self, from: data)
}

// Call site — no manual threading needed
@MainActor
func loadProfile() async {
    do {
        let user = try await fetchUser(id: "42")
        display(user)                   // already on MainActor
    } catch {
        showError(error)
    }
}
```

**Migration checklist:**
1. Add `async throws` (or just `async`) to the function signature
2. Remove the `completion` / `handler` / `callback` parameter
3. Return the value directly — `throw` on error
4. Replace `URLSession.dataTask` with `URLSession.data(from:)` (async)
5. Update all call sites to `try await` / `await`
6. If bridging a third-party callback API, use `withCheckedThrowingContinuation`

**Bridging a legacy callback with continuation:**
```swift
func fetchUser(id: String) async throws -> User {
    try await withCheckedThrowingContinuation { continuation in
        legacyService.fetchUser(id: id) { result in
            continuation.resume(with: result)
        }
    }
}
```

---

## References

- [SE-0296 – Async/await](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
- [SE-0300 – Continuations](https://github.com/apple/swift-evolution/blob/main/proposals/0300-continuation.md)
