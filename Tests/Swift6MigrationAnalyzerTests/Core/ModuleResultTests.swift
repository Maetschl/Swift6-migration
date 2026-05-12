import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("ModuleResult")
struct ModuleResultTests {

    // MARK: - Basic construction

    @Test("name and qualifiedName are stored correctly")
    func nameAndQualifiedName() {
        let m = makeModule(name: "Networking", qualifiedName: "Core/Networking")
        #expect(m.name == "Networking")
        #expect(m.qualifiedName == "Core/Networking")
    }

    @Test("aggregateFindings defaults to own findings count when not supplied")
    func aggregateFindingsDefaultsToFindingsCount() {
        let findings = [
            Finding(file: "F.swift", line: 1, severity: .error, rule: "R", message: "m"),
            Finding(file: "F.swift", line: 2, severity: .warning, rule: "R2", message: "m2")
        ]
        let m = makeModule(findings: findings)
        #expect(m.aggregateFindings == 2)
    }

    @Test("aggregateFindings can be overridden with explicit value")
    func aggregateFindingsExplicitValue() {
        let findings = [
            Finding(file: "F.swift", line: 1, severity: .error, rule: "R", message: "m")
        ]
        let m = ModuleResult(
            name: "M", qualifiedName: "M", path: "/M",
            status: .migrated, aggregateStatus: .pendingMigration,
            score: 0, aggregateScore: 1.5,
            fileCount: 1, totalLinesOfCode: 10,
            findings: findings,
            aggregateFindings: 5
        )
        #expect(m.aggregateFindings == 5)
    }

    @Test("aggregateMigrationIndicators defaults to own indicators when not supplied")
    func aggregateMigrationIndicatorsDefault() {
        let indicators = MigrationIndicators(
            actorDeclarationCount: 2,
            mainActorAnnotationCount: 1,
            asyncFunctionCount: 3,
            awaitUsageCount: 4,
            sendableConformanceCount: 1
        )
        let m = ModuleResult(
            name: "M", qualifiedName: "M", path: "/M",
            status: .migrated, aggregateStatus: .migrated,
            score: 0, aggregateScore: 0,
            fileCount: 1, totalLinesOfCode: 10,
            findings: [],
            migrationIndicators: indicators
        )
        #expect(m.aggregateMigrationIndicators.actorDeclarationCount == 2)
        #expect(m.aggregateMigrationIndicators.asyncFunctionCount == 3)
    }

    @Test("depth defaults to 0")
    func depthDefaultsToZero() {
        let m = makeModule()
        #expect(m.depth == 0)
    }

    @Test("parentQualifiedName defaults to nil")
    func parentQualifiedNameDefaultsToNil() {
        let m = makeModule()
        #expect(m.parentQualifiedName == nil)
    }

    @Test("childQualifiedNames defaults to empty")
    func childQualifiedNamesDefaultsToEmpty() {
        let m = makeModule()
        #expect(m.childQualifiedNames.isEmpty)
    }

    // MARK: - Codable round-trip

    @Test("Codable round-trip for a simple migrated module")
    func codableRoundTripMigrated() throws {
        let original = makeModule(
            name: "Auth",
            qualifiedName: "Features/Auth",
            status: .migrated,
            score: 0.0
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModuleResult.self, from: data)

        #expect(decoded.name           == original.name)
        #expect(decoded.qualifiedName  == original.qualifiedName)
        #expect(decoded.status         == original.status)
        #expect(decoded.score          == original.score)
        #expect(decoded.fileCount      == original.fileCount)
        #expect(decoded.depth          == original.depth)
    }

    @Test("Codable round-trip for a pending module with findings")
    func codableRoundTripPendingWithFindings() throws {
        let findings = [
            Finding(file: "Auth.swift", line: 12, column: 3,
                    severity: .error, rule: "DispatchQueueRule", message: "Use @MainActor")
        ]
        let original = ModuleResult(
            name: "Auth", qualifiedName: "Features/Auth", path: "/proj/Features/Auth",
            status: .pendingMigration, aggregateStatus: .pendingMigration,
            score: 0.7, aggregateScore: 0.7,
            fileCount: 3, totalLinesOfCode: 120,
            findings: findings,
            depth: 1,
            parentQualifiedName: "Features",
            childQualifiedNames: []
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModuleResult.self, from: data)

        #expect(decoded.status.isPendingMigration)
        #expect(decoded.score == 0.7)
        #expect(decoded.findings.count == 1)
        #expect(decoded.findings[0].rule == "DispatchQueueRule")
        #expect(decoded.findings[0].line == 12)
        #expect(decoded.depth == 1)
        #expect(decoded.parentQualifiedName == "Features")
    }

    @Test("Codable round-trip preserves childQualifiedNames")
    func codableRoundTripChildNames() throws {
        let original = ModuleResult(
            name: "Core", qualifiedName: "Core", path: "/Core",
            status: .migrated, aggregateStatus: .pendingMigration,
            score: 0, aggregateScore: 1.2,
            fileCount: 0, totalLinesOfCode: 0,
            findings: [],
            childQualifiedNames: ["Core/Auth", "Core/Network"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModuleResult.self, from: data)
        #expect(decoded.childQualifiedNames.sorted() == ["Core/Auth", "Core/Network"])
    }

    @Test("Codable round-trip preserves migrated-with-warnings aggregateStatus")
    func codableRoundTripAggregateStatusWarnings() throws {
        let original = ModuleResult(
            name: "UI", qualifiedName: "UI", path: "/UI",
            status: MigrationStatus([.migrated, .warnings]),
            aggregateStatus: MigrationStatus([.migrated, .warnings]),
            score: 0, aggregateScore: 0,
            fileCount: 2, totalLinesOfCode: 50,
            findings: []
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModuleResult.self, from: data)
        #expect(decoded.status.isMigrated)
        #expect(decoded.status.hasWarnings)
        #expect(decoded.aggregateStatus.hasWarnings)
    }

    @Test("Codable round-trip preserves MigrationIndicators")
    func codableRoundTripMigrationIndicators() throws {
        let indicators = MigrationIndicators(
            actorDeclarationCount: 3,
            mainActorAnnotationCount: 5,
            asyncFunctionCount: 8,
            awaitUsageCount: 10,
            sendableConformanceCount: 2
        )
        let original = ModuleResult(
            name: "Net", qualifiedName: "Net", path: "/Net",
            status: .migrated, aggregateStatus: .migrated,
            score: 0, aggregateScore: 0,
            fileCount: 4, totalLinesOfCode: 200,
            findings: [],
            migrationIndicators: indicators
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModuleResult.self, from: data)
        #expect(decoded.migrationIndicators.actorDeclarationCount == 3)
        #expect(decoded.migrationIndicators.asyncFunctionCount == 8)
        #expect(decoded.migrationIndicators.sendableConformanceCount == 2)
    }

    // MARK: - Helpers

    private func makeModule(
        name: String = "Module",
        qualifiedName: String = "Module",
        status: MigrationStatus = .migrated,
        aggregateStatus: MigrationStatus = .migrated,
        score: Double = 0.0,
        aggregateScore: Double = 0.0,
        fileCount: Int = 1,
        totalLinesOfCode: Int = 10,
        findings: [Finding] = []
    ) -> ModuleResult {
        ModuleResult(
            name: name,
            qualifiedName: qualifiedName,
            path: "/\(name)",
            status: status,
            aggregateStatus: aggregateStatus,
            score: score,
            aggregateScore: aggregateScore,
            fileCount: fileCount,
            totalLinesOfCode: totalLinesOfCode,
            findings: findings
        )
    }
}
