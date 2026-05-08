# MainActorMissingRule

**Severity:** ⚠️ warning  
**Complexity Weight:** 0.6  
**Category:** Swift 6 Concurrency (default)

---

## What It Detects

Subclasses of UIKit/AppKit base types that do **not** have an explicit `@MainActor` annotation:

`UIViewController`, `UITableViewController`, `UICollectionViewController`,
`UINavigationController`, `UITabBarController`, `UIPageViewController`,
`UISplitViewController`, `UIView`, `UIControl`, `UITableViewCell`,
`UICollectionViewCell`, `UITableViewHeaderFooterView`,
`NSViewController`, `NSView`, `NSWindowController`, `NSWindow`,
`UIHostingController`.

---

## Why It Matters

UIKit and AppKit types carry an implicit `@MainActor` annotation in the SDK. Swift 6 requires you to make that isolation **explicit** in your own subclasses. Without it, calling methods on the subclass from a non-isolated async context generates:

> *"Call to main actor-isolated instance method 'viewDidLoad()' in a synchronous nonisolated context"*

---

## ❌ Wrong

```swift
class HomeViewController: UIViewController {   // ← missing @MainActor
    var viewModel = HomeViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.load()
    }
}

class ProductCell: UITableViewCell {           // ← missing @MainActor
    @IBOutlet weak var titleLabel: UILabel!
}
```

---

## ✅ Correct

```swift
@MainActor
class HomeViewController: UIViewController {
    var viewModel = HomeViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.load()
    }
}

@MainActor
class ProductCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
}
```

**If a method needs to run off the main thread, mark it `nonisolated`:**
```swift
@MainActor
class HomeViewController: UIViewController {
    nonisolated func backgroundTask() async {
        // runs off main thread — no access to @MainActor properties here
        let data = await fetchData()
        await MainActor.run { self.display(data) }
    }
}
```

---

## References

- [SE-0316 – Global actors](https://github.com/apple/swift-evolution/blob/main/proposals/0316-global-actors.md)
