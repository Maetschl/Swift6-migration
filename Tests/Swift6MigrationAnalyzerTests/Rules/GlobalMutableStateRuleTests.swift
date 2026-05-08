import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("GlobalMutableStateRule")
struct GlobalMutableStateRuleTests {

    let rule = GlobalMutableStateRule()

    // MARK: - Detection

    @Test("Detects var at file scope")
    func detectsFileScope() {
        let source = "var sharedCache: [String: Any] = [:]"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "GlobalMutableStateRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects multiple global vars")
    func detectsMultipleGlobalVars() {
        let source = """
        var counter = 0
        var registry: [String] = []
        var isReady = false
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 3)
    }

    @Test("Finding message includes variable name")
    func messageIncludesVariableName() {
        let source = "var globalFlag = false"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("globalFlag"))
    }

    @Test("Finding message mentions actor isolation or Swift 6")
    func messageDescribesFix() {
        let source = "var x = 0"
        let result = findings(from: rule, source: source)
        #expect(result[0].message.contains("actor") || result[0].message.contains("Swift 6"))
    }

    // MARK: - Non-detection

    @Test("Does not flag let at file scope (immutable)")
    func ignoresLetAtFileScope() {
        let source = "let constant = 42"
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag var inside a struct")
    func ignoresVarInsideStruct() {
        let source = """
        struct Config {
            var value: Int = 0
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag var inside a class")
    func ignoresVarInsideClass() {
        let source = """
        class Manager {
            var state: String = ""
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag var inside a function")
    func ignoresVarInsideFunction() {
        let source = """
        func compute() {
            var result = 0
            result += 1
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag computed var at file scope")
    func ignoresComputedVar() {
        let source = """
        var currentDate: String { Date().description }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
