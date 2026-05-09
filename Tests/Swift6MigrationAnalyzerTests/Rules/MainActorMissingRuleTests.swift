import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("MainActorMissingRule")
struct MainActorMissingRuleTests {

    let rule = MainActorMissingRule()

    // MARK: - Detection

    @Test("Detects UIViewController subclass without @MainActor")
    func detectsUIViewController() {
        let source = """
        class HomeViewController: UIViewController {
            override func viewDidLoad() { super.viewDidLoad() }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "MainActorMissingRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects UIView subclass without @MainActor")
    func detectsUIView() {
        let source = "class CardView: UIView { }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects UITableViewCell subclass")
    func detectsUITableViewCell() {
        let source = "class ProductCell: UITableViewCell { }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message includes class name and base class")
    func messageIncludesNames() {
        let source = "class MyVC: UIViewController { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("MyVC"))
        #expect(result[0].message.contains("UIViewController"))
    }

    // MARK: - Non-detection

    @Test("Does not flag class with @MainActor")
    func ignoresMainActorAnnotatedClass() {
        let source = """
        @MainActor
        class HomeViewController: UIViewController { }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag non-UIKit classes")
    func ignoresNonUIKitClasses() {
        let source = "class NetworkManager: NSObject { }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag structs")
    func ignoresStructs() {
        let source = "struct MyView: UIView { }"
        // Structs can't inherit, but should not cause a crash
        let result = findings(from: rule, source: source)
        // No finding expected (struct, not class)
        #expect(result.isEmpty)
    }
}
