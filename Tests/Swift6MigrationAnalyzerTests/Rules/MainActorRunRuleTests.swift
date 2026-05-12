import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("MainActorRunRule")
struct MainActorRunRuleTests {
    let rule = MainActorRunRule()

    @Test("Detects await MainActor.run capturing self in non-isolated class")
    func detectsBasicCapture() {
        let source = "class X { var v = 0; func f() async { await MainActor.run { _ = self.v } } }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "MainActorRunRule")
        #expect(result[0].severity == .error)
    }

    @Test("Detects self mutation inside await MainActor.run")
    func detectsSelfMutation() {
        let source = "class VM { var name = \"\"; func load() async { await MainActor.run { self.name = \"x\" } } }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].severity == .error)
        #expect(result[0].message.contains("VM"))
    }

    @Test("Detects multiple await MainActor.run sites")
    func detectsMultiple() {
        let source = "class C { var x = 0; func a() async { await MainActor.run { _ = self.x } }; func b() async { await MainActor.run { self.x = 1 } } }"
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    @Test("Does not flag @MainActor class")
    func doesNotFlagMainActorClass() {
        let source = "@MainActor class Safe { var s = \"\"; func f() async { await MainActor.run { self.s = \"ok\" } } }"
        #expect(findings(from: rule, source: source).isEmpty)
    }

    @Test("Does not flag actor")
    func doesNotFlagActor() {
        let source = "actor DS { var items: [String] = []; func add() async { await MainActor.run { _ = self.items.count } } }"
        #expect(findings(from: rule, source: source).isEmpty)
    }

    @Test("Does not flag struct")
    func doesNotFlagStruct() {
        let source = "struct S { var n = \"\"; func f() async { await MainActor.run { _ = self.n } } }"
        #expect(findings(from: rule, source: source).isEmpty)
    }

    @Test("Does not flag when no self in closure")
    func doesNotFlagNoSelf() {
        let source = "class C { func f() async { let v = 1; await MainActor.run { print(v) } } }"
        #expect(findings(from: rule, source: source).isEmpty)
    }

    @Test("MainActorRunRule has weight 0.7")
    func hasCorrectWeight() {
        #expect(FindingComplexity.weight(for: "MainActorRunRule") == 0.7)
    }

    @Test("MainActorRunRule contributes to errorScore")
    func contributesToErrorScore() {
        let f = makeFinding(severity: .error, rule: "MainActorRunRule")
        #expect(FindingComplexity.errorScore(for: [f]) == 0.7)
    }
}
