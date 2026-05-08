# ForceUnwrapRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.3  
**Category:** Code Quality (opt-in via `--include-quality-rules`)

---

## What It Detects

Force-unwrap operator `!` applied to optional values: `value!`, `array[i]!`, `function()!`, `as! Type`.

---

## Why It Matters

Force-unwrap crashes the process with `EXC_BAD_INSTRUCTION` when the value is `nil`. Crashes in concurrent code are harder to debug because they may occur on background threads or inside actors with incomplete stack traces and no recovery path.

---

## ❌ Wrong

```swift
let user = userCache["id42"]!          // crashes if key missing
let url  = URL(string: rawString)!     // crashes on malformed string
let cell = tableView.dequeueReusableCell(
    withIdentifier: "Cell", for: indexPath) as! ProductCell   // crashes on wrong type

// In async context — crash terminates the actor
func loadAvatar() async {
    let data = try! await URLSession.shared.data(from: avatarURL!).0
    avatarImage = UIImage(data: data)!
}
```

---

## ✅ Correct

**`guard let` — early exit with logging:**
```swift
guard let user = userCache["id42"] else {
    logger.error("User not found for id42")
    return
}
use(user)
```

**`if let` — conditional branch:**
```swift
if let url = URL(string: rawString) {
    open(url)
} else {
    showInvalidURLError()
}
```

**Nil coalescing — provide a safe default:**
```swift
let name = profile?.name ?? "Anonymous"
```

**Safe cast with `as?`:**
```swift
guard let cell = tableView.dequeueReusableCell(
    withIdentifier: "Cell", for: indexPath) as? ProductCell else {
    assertionFailure("Wrong cell type registered for 'Cell' identifier")
    return
}
cell.configure(with: item)
```

**Async context — propagate errors:**
```swift
func loadAvatar() async throws {
    guard let url = avatarURL else { throw AvatarError.missingURL }
    let (data, _) = try await URLSession.shared.data(from: url)
    guard let image = UIImage(data: data) else { throw AvatarError.invalidImageData }
    avatarImage = image
}
```

---

## References

- [Swift Book – Optional Chaining](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/optionalchaining/)
- [Swift Book – Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
