import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("ObservableObjectRule")
struct ObservableObjectRuleTests {

    let rule = ObservableObjectRule()

    // MARK: - Detection

    @Test("Detects ObservableObject on a class")
    func detectsOnClass() {
        let source = """
        class HomeViewModel: ObservableObject {
            @Published var title = ""
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "ObservableObjectRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects ObservableObject alongside other protocols")
    func detectsAlongsideOtherProtocols() {
        let source = "class VM: Identifiable, ObservableObject { var id = UUID() }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects multiple ObservableObject conformances in one file")
    func detectsMultiple() {
        let source = """
        class ViewModelA: ObservableObject { }
        class ViewModelB: ObservableObject { }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    @Test("Finding message mentions @Observable")
    func messagesMentionObservable() {
        let source = "class VM: ObservableObject { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("@Observable") || result[0].message.contains("Observable"))
    }

    // MARK: - Non-detection

    @Test("Does not flag non-ObservableObject protocols")
    func ignoresOtherProtocols() {
        let source = """
        class Manager: NSObject, Codable { }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag plain class with no conformances")
    func ignoresPlainClass() {
        let source = "class Service { var name = \"\" }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}

@Suite("SynchronizationPrimitiveRule")
struct SynchronizationPrimitiveRuleTests {

    let rule = SynchronizationPrimitiveRule()

    // MARK: - Detection

    @Test("Detects NSLock via type annotation")
    func detectsNSLockTypeAnnotation() {
        let source = """
        class Service {
            var lock: NSLock = NSLock()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "SynchronizationPrimitiveRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects NSLock via initializer expression")
    func detectsNSLockInitializer() {
        let source = "let myLock = NSLock()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects NSRecursiveLock")
    func detectsNSRecursiveLock() {
        let source = "let recursiveLock = NSRecursiveLock()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects DispatchSemaphore")
    func detectsDispatchSemaphore() {
        let source = "let sem = DispatchSemaphore(value: 1)"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message mentions actor migration")
    func messageMentionsActor() {
        let source = "let lock = NSLock()"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor"))
    }

    // MARK: - Non-detection

    @Test("Does not flag unrelated type usage")
    func ignoresUnrelatedTypes() {
        let source = """
        let queue = OperationQueue()
        let name = "Hello"
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}

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

@Suite("NotificationCenterRule")
struct NotificationCenterRuleTests {

    let rule = NotificationCenterRule()

    // MARK: - Detection

    @Test("Detects NotificationCenter.default.addObserver")
    func detectsAddObserver() {
        let source = """
        NotificationCenter.default.addObserver(self, selector: #selector(handle), name: .NSManagedObjectContextDidSave, object: nil)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "NotificationCenterRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects NotificationCenter.default.post")
    func detectsPost() {
        let source = """
        NotificationCenter.default.post(name: .init("MyEvent"), object: nil)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message mentions actor isolation or async")
    func messageDescribesFix() {
        let source = "NotificationCenter.default.addObserver(self, selector: #selector(h), name: .NSManagedObjectContextDidSave, object: nil)"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor") || result[0].message.contains("async") || result[0].message.contains("MainActor"))
    }

    // MARK: - Non-detection

    @Test("Does not flag unrelated function calls")
    func ignoresUnrelatedCalls() {
        let source = "URLSession.shared.dataTask(with: url) { _, _, _ in }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}

@Suite("OperationQueueMainRule")
struct OperationQueueMainRuleTests {

    let rule = OperationQueueMainRule()

    // MARK: - Detection

    @Test("Detects OperationQueue.main.addOperation")
    func detectsAddOperation() {
        let source = "OperationQueue.main.addOperation { print(\"done\") }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "OperationQueueMainRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects OperationQueue.main in chained calls")
    func detectsChainedCall() {
        let source = """
        OperationQueue.main.addOperation(BlockOperation {
            self.tableView.reloadData()
        })
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
    }

    @Test("Finding message mentions @MainActor")
    func messagesMentionMainActor() {
        let source = "OperationQueue.main.addOperation { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("MainActor") || result[0].message.contains("concurrency"))
    }

    // MARK: - Non-detection

    @Test("Does not flag OperationQueue() without main")
    func ignoresBackgroundQueue() {
        let source = """
        let queue = OperationQueue()
        queue.addOperation { print("bg") }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
