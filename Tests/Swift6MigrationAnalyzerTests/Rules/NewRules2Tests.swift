import Testing
@testable import Swift6MigrationAnalyzerCore

// MARK: - TimerRule

@Suite("TimerRule")
struct TimerRuleTests {

    let rule = TimerRule()

    @Test("Detects Timer.scheduledTimer with block")
    func detectsScheduledTimerBlock() {
        let source = """
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.refresh()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "TimerRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects Timer.scheduledTimer with target/selector")
    func detectsScheduledTimerSelector() {
        let source = """
        Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(tick), userInfo: nil, repeats: false)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects Timer(timeInterval:repeats:block:) initializer")
    func detectsTimerInit() {
        let source = "let t = Timer(timeInterval: 0.5, repeats: true) { _ in }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message mentions Task.sleep or AsyncStream")
    func messageDescribesMigration() {
        let source = "Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("Task.sleep") || result[0].message.contains("AsyncStream"))
    }

    @Test("Does not flag unrelated calls")
    func ignoresUnrelated() {
        let source = "URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}

// MARK: - CombineRule

@Suite("CombineRule")
struct CombineRuleTests {

    let rule = CombineRule()

    @Test("Detects .sink closure")
    func detectsSink() {
        let source = """
        publisher
            .sink { value in self.label = value }
            .store(in: &cancellables)
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result.contains { $0.rule == "CombineRule" && $0.message.contains("sink") })
    }

    @Test("Detects assign(to:on:)")
    func detectsAssign() {
        let source = "publisher.assign(to: \\.title, on: self)"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "CombineRule")
    }

    @Test("Detects AnyCancellable stored property")
    func detectsAnyCancellable() {
        let source = """
        class ViewModel {
            var cancellable: AnyCancellable?
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "CombineRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects Set<AnyCancellable> stored property")
    func detectsAnyCancellableSet() {
        let source = """
        class VM {
            var cancellables: Set<AnyCancellable> = []
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Does not flag plain property unrelated to Combine")
    func ignoresUnrelated() {
        let source = "var name: String = \"\""
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}

// MARK: - ThreadRule

@Suite("ThreadRule")
struct ThreadRuleTests {

    let rule = ThreadRule()

    @Test("Detects Thread.detachNewThread")
    func detectsDetachNewThread() {
        let source = "Thread.detachNewThread { self.work() }"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result[0].rule == "ThreadRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects Thread(block:) initializer")
    func detectsThreadBlockInit() {
        let source = "let t = Thread { self.process() }"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
    }

    @Test("Detects Thread.isMainThread member access")
    func detectsIsMainThread() {
        let source = """
        if Thread.isMainThread {
            updateUI()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
        #expect(result.contains { $0.message.contains("isMainThread") })
    }

    @Test("Detects Thread.main member access")
    func detectsThreadMain() {
        let source = "let t = Thread.main"
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
    }

    @Test("Finding message mentions actor isolation")
    func messageDescribesFix() {
        let source = "Thread.detachNewThread { }"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor") || result[0].message.contains("MainActor"))
    }
}

// MARK: - NonisolatedUnsafeRule

@Suite("NonisolatedUnsafeRule")
struct NonisolatedUnsafeRuleTests {

    let rule = NonisolatedUnsafeRule()

    @Test("Detects nonisolated(unsafe) on stored property")
    func detectsNonisolatedUnsafe() {
        let source = """
        class Cache {
            nonisolated(unsafe) var shared: [String: Any] = [:]
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "NonisolatedUnsafeRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects nonisolated(unsafe) at file scope")
    func detectsAtFileScope() {
        let source = "nonisolated(unsafe) var globalCache: [String: Any] = [:]"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Finding message mentions audit and data races")
    func messageDescribesRisk() {
        let source = "nonisolated(unsafe) var x = 0"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("audit") || result[0].message.contains("data race"))
    }

    @Test("Does not flag regular nonisolated computed property")
    func ignoresNonisolatedComputedProperty() {
        let source = """
        actor MyActor {
            nonisolated var description: String { "MyActor" }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag regular stored var without modifier")
    func ignoresRegularVar() {
        let source = "var counter = 0"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}

// MARK: - PreconcurrencyRule

@Suite("PreconcurrencyRule")
struct PreconcurrencyRuleTests {

    let rule = PreconcurrencyRule()

    @Test("Detects @preconcurrency import")
    func detectsPreconcurrencyImport() {
        let source = "@preconcurrency import SomeOldModule"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "PreconcurrencyRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects multiple @preconcurrency imports")
    func detectsMultipleImports() {
        let source = """
        @preconcurrency import ModuleA
        import Foundation
        @preconcurrency import ModuleB
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    @Test("Finding message mentions the imported module name")
    func messageIncludesModuleName() {
        let source = "@preconcurrency import LegacyNetworking"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("LegacyNetworking"))
    }

    @Test("Does not flag regular import without @preconcurrency")
    func ignoresRegularImport() {
        let source = "import Foundation"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}

// MARK: - DispatchGroupRule

@Suite("DispatchGroupRule")
struct DispatchGroupRuleTests {

    let rule = DispatchGroupRule()

    @Test("Detects DispatchGroup() initializer in variable")
    func detectsDispatchGroupInit() {
        let source = "let group = DispatchGroup()"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "DispatchGroupRule")
        #expect(result[0].severity == .warning)
    }

    @Test("Detects DispatchGroup via type annotation")
    func detectsDispatchGroupTypeAnnotation() {
        let source = """
        class Loader {
            var group: DispatchGroup = DispatchGroup()
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count >= 1)
    }

    @Test("Finding message mentions withTaskGroup or async let")
    func messageDescribesMigration() {
        let source = "let g = DispatchGroup()"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("withTaskGroup") || result[0].message.contains("async let"))
    }

    @Test("Does not flag unrelated DispatchQueue usage")
    func ignoresDispatchQueue() {
        let source = "DispatchQueue.main.async { print(\"hi\") }"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
