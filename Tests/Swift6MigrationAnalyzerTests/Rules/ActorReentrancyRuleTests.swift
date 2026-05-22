import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("ActorReentrancyRule")
struct ActorReentrancyRuleTests {

    let rule = ActorReentrancyRule()

    @Test("Detects external await in async actor method as .warning")
    func detectsExternalAwait() {
        let source = """
        actor Cache {
            let networkService = NetworkService()

            func refresh() async {
                let fresh = await networkService.fetchItems()
                print(fresh)
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
        #expect(result[0].rule == "ActorReentrancyRule")
        #expect(result[0].severity == .warning)
        #expect(result[0].message.contains("refresh"))
    }

    @Test("Reports one finding per method even with multiple external awaits")
    func reportsOneFindingPerMethod() {
        let source = """
        actor Cache {
            let primary = PrimaryService()
            let backup = BackupService()

            func refresh() async {
                _ = await primary.fetch()
                _ = await backup.fetch()
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 1)
    }

    @Test("Detects multiple actor methods independently")
    func detectsMultipleMethods() {
        let source = """
        actor Cache {
            let service = Service()

            func refresh() async { _ = await service.fetch() }
            func warm() async { _ = await service.prefetch() }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.count == 2)
    }

    @Test("Does not flag await on self member access")
    func ignoresSelfAwait() {
        let source = """
        actor Cache {
            func refresh() async {
                await self.loadFromDisk()
            }

            func loadFromDisk() async { }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag try await on self member access")
    func ignoresTrySelfAwait() {
        let source = """
        actor Cache {
            func refresh() async throws {
                try await self.loadFromDisk()
            }

            func loadFromDisk() async throws { }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag external await outside actors")
    func ignoresNonActorAsyncMethod() {
        let source = """
        struct Loader {
            let service = Service()
            func refresh() async {
                _ = await service.fetch()
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }

    @Test("Does not flag non-async actor methods")
    func ignoresNonAsyncActorMethod() {
        let source = """
        actor Cache {
            func refresh() {
                print("sync")
            }
        }
        """
        let result = findings(from: rule, source: source)
        #expect(result.isEmpty)
    }
}
