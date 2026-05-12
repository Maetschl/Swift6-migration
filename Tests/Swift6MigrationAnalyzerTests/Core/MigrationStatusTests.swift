import Testing
import Foundation
@testable import Swift6MigrationAnalyzerCore

@Suite("MigrationStatus")
struct MigrationStatusTests {

    // MARK: - Static convenience factories

    @Test("migrated convenience has only the migrated tag")
    func migratedConvenience() {
        let s = MigrationStatus.migrated
        #expect(s.tags == [.migrated])
    }

    @Test("pendingMigration convenience has only the pendingMigration tag")
    func pendingConvenience() {
        let s = MigrationStatus.pendingMigration
        #expect(s.tags == [.pendingMigration])
    }

    // MARK: - Query helpers

    @Test("isMigrated is true when only migrated tag present")
    func isMigratedForMigratedStatus() {
        #expect(MigrationStatus.migrated.isMigrated)
    }

    @Test("isMigrated is true for migrated-with-warnings")
    func isMigratedForWarningsStatus() {
        let s = MigrationStatus([.migrated, .warnings])
        #expect(s.isMigrated)
    }

    @Test("isMigrated is false when pendingMigration tag present")
    func isMigratedFalseForPending() {
        #expect(!MigrationStatus.pendingMigration.isMigrated)
    }

    @Test("isPendingMigration is true when pendingMigration tag present")
    func isPendingWhenPending() {
        #expect(MigrationStatus.pendingMigration.isPendingMigration)
    }

    @Test("isPendingMigration is false when only migrated tag present")
    func isNotPendingWhenMigrated() {
        #expect(!MigrationStatus.migrated.isPendingMigration)
    }

    @Test("hasWarnings is true when warnings tag present alongside migrated")
    func hasWarningsWhenWarningsTagPresent() {
        let s = MigrationStatus([.migrated, .warnings])
        #expect(s.hasWarnings)
    }

    @Test("hasWarnings is false when only migrated tag present")
    func noWarningsForCleanMigrated() {
        #expect(!MigrationStatus.migrated.hasWarnings)
    }

    @Test("hasWarnings is true when warnings tag present alongside pendingMigration")
    func hasWarningsAlongsidePending() {
        let s = MigrationStatus([.pendingMigration, .warnings])
        #expect(s.hasWarnings)
    }

    // MARK: - rawValue

    @Test("rawValue for migrated is 'Migrated'")
    func rawValueMigrated() {
        #expect(MigrationStatus.migrated.rawValue == "Migrated")
    }

    @Test("rawValue for pendingMigration is 'Pending Migration'")
    func rawValuePending() {
        #expect(MigrationStatus.pendingMigration.rawValue == "Pending Migration")
    }

    @Test("rawValue for migrated-with-warnings is 'Migrated · Warnings'")
    func rawValueMigratedWithWarnings() {
        let s = MigrationStatus([.migrated, .warnings])
        #expect(s.rawValue == "Migrated · Warnings")
    }

    @Test("rawValue for pending-with-warnings starts with 'Pending Migration'")
    func rawValuePendingWithWarnings() {
        let s = MigrationStatus([.pendingMigration, .warnings])
        #expect(s.rawValue.hasPrefix("Pending Migration"))
        #expect(s.rawValue.contains("Warnings"))
    }

    // MARK: - icon

    @Test("icon is ✅ for migrated")
    func iconMigrated() {
        #expect(MigrationStatus.migrated.icon == "✅")
    }

    @Test("icon is ⚠️ for migrated-with-warnings")
    func iconWarnings() {
        let s = MigrationStatus([.migrated, .warnings])
        #expect(s.icon == "⚠️")
    }

    @Test("icon is ⏳ for pendingMigration")
    func iconPending() {
        #expect(MigrationStatus.pendingMigration.icon == "⏳")
    }

    @Test("icon is ⏳ for pending-with-warnings (pending takes priority)")
    func iconPendingWithWarnings() {
        let s = MigrationStatus([.pendingMigration, .warnings])
        #expect(s.icon == "⏳")
    }

    // MARK: - htmlClass

    @Test("htmlClass is 'migrated' for migrated status")
    func htmlClassMigrated() {
        #expect(MigrationStatus.migrated.htmlClass == "migrated")
    }

    @Test("htmlClass is 'tag-warnings' for migrated-with-warnings")
    func htmlClassWarnings() {
        let s = MigrationStatus([.migrated, .warnings])
        #expect(s.htmlClass == "tag-warnings")
    }

    @Test("htmlClass is 'pending' for pendingMigration")
    func htmlClassPending() {
        #expect(MigrationStatus.pendingMigration.htmlClass == "pending")
    }

    // MARK: - badgesHTML

    @Test("badgesHTML for migrated contains migrated span")
    func badgesHTMLMigrated() {
        let html = MigrationStatus.migrated.badgesHTML
        #expect(html.contains("class=\"status-badge migrated\""))
        #expect(html.contains("✅"))
    }

    @Test("badgesHTML for pending contains pending span")
    func badgesHTMLPending() {
        let html = MigrationStatus.pendingMigration.badgesHTML
        #expect(html.contains("class=\"status-badge pending\""))
        #expect(html.contains("⏳"))
    }

    @Test("badgesHTML for migrated-with-warnings contains two spans")
    func badgesHTMLMigratedWithWarnings() {
        let s = MigrationStatus([.migrated, .warnings])
        let html = s.badgesHTML
        #expect(html.contains("class=\"status-badge migrated\""))
        #expect(html.contains("class=\"status-badge tag-warnings\""))
    }

    // MARK: - badgesMarkdown

    @Test("badgesMarkdown for migrated contains ✅ Migrated")
    func badgesMarkdownMigrated() {
        #expect(MigrationStatus.migrated.badgesMarkdown == "✅ Migrated")
    }

    @Test("badgesMarkdown for pending contains ⏳ Pending Migration")
    func badgesMarkdownPending() {
        #expect(MigrationStatus.pendingMigration.badgesMarkdown == "⏳ Pending Migration")
    }

    @Test("badgesMarkdown for migrated-with-warnings contains both tokens")
    func badgesMarkdownMigratedWithWarnings() {
        let s = MigrationStatus([.migrated, .warnings])
        let md = s.badgesMarkdown
        #expect(md.contains("✅ Migrated"))
        #expect(md.contains("⚠️ Warnings"))
    }

    // MARK: - Codable round-trip

    @Test("Codable round-trip for migrated status")
    func codableRoundTripMigrated() throws {
        let original = MigrationStatus.migrated
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MigrationStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("Codable round-trip for pendingMigration status")
    func codableRoundTripPending() throws {
        let original = MigrationStatus.pendingMigration
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MigrationStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("Codable round-trip for migrated-with-warnings status")
    func codableRoundTripMigratedWithWarnings() throws {
        let original = MigrationStatus([.migrated, .warnings])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MigrationStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("Codable encodes status as array of strings")
    func codableEncodesAsArray() throws {
        let data = try JSONEncoder().encode(MigrationStatus.migrated)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String])
    }

    @Test("Codable decodes unknown tag strings gracefully (skips them)")
    func codableDecodesUnknownTagGracefully() throws {
        let json = "[\"Migrated\", \"UnknownFuturTag\"]".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MigrationStatus.self, from: json)
        #expect(decoded.tags.contains(.migrated))
        #expect(decoded.tags.count == 1)
    }

    // MARK: - Equatable / Hashable

    @Test("Two migrated statuses are equal")
    func equalityMigrated() {
        #expect(MigrationStatus.migrated == MigrationStatus([.migrated]))
    }

    @Test("migrated and pendingMigration are not equal")
    func inequalityDifferentStatuses() {
        #expect(MigrationStatus.migrated != MigrationStatus.pendingMigration)
    }

    @Test("MigrationStatus can be used as a dictionary key")
    func usableAsDictionaryKey() {
        var dict: [MigrationStatus: Int] = [:]
        dict[MigrationStatus.migrated] = 1
        dict[MigrationStatus.pendingMigration] = 2
        #expect(dict[MigrationStatus.migrated] == 1)
        #expect(dict[MigrationStatus.pendingMigration] == 2)
    }
}
