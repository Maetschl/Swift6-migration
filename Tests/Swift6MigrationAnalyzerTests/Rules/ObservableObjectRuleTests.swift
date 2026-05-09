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
