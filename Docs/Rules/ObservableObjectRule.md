# ObservableObjectRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.5  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Classes that conform to `ObservableObject` (typically combined with `@Published` properties).

---

## Why It Matters

`ObservableObject` + `@Published` uses a Combine-based observation system that requires `objectWillChange` to be published on the main thread. In Swift 6 strict mode, mutating `@Published` properties off the main actor produces isolation errors. The `@Observable` macro (Swift 5.9+) replaces this with compiler-level observation that integrates naturally with Swift 6 actor isolation.

---

## ❌ Wrong

```swift
import Combine

class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var avatarURL: URL?
    @Published var isLoading = false

    func load() async {
        isLoading = true                          // ← may be a Swift 6 error if not on MainActor
        let profile = try? await api.fetchProfile()
        name = profile?.name ?? ""
        isLoading = false
    }
}

// SwiftUI usage
struct ProfileView: View {
    @StateObject var viewModel = ProfileViewModel()  // ← @StateObject tied to ObservableObject
    var body: some View {
        Text(viewModel.name)
    }
}
```

---

## ✅ Correct

```swift
import Observation

@Observable
@MainActor
class ProfileViewModel {
    var name: String = ""
    var avatarURL: URL?
    var isLoading = false

    func load() async {
        isLoading = true
        let profile = try? await api.fetchProfile()
        name = profile?.name ?? ""
        isLoading = false
    }
}

// SwiftUI usage — no @StateObject needed
struct ProfileView: View {
    @State var viewModel = ProfileViewModel()  // plain @State
    var body: some View {
        Text(viewModel.name)
    }
}
```

**Migration checklist:**
1. Add `import Observation`
2. Replace `class Foo: ObservableObject` → `@Observable class Foo`
3. Remove all `@Published` property wrappers
4. Remove `@ObservedObject` / `@StateObject` at call sites — use `@State` or plain `let`
5. Add `@MainActor` if the type mutates UI state

---

## References

- [SE-0395 – Observation](https://github.com/apple/swift-evolution/blob/main/proposals/0395-observability.md)
