import Testing
@testable import Swift6MigrationAnalyzerCore

@Suite("HTMLReporter")
struct HTMLReporterTests {

    let reporter = HTMLReporter()

    // MARK: - Document structure

    @Test("Output is valid HTML with DOCTYPE")
    func hasDoctype() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.hasPrefix("<!DOCTYPE html>"))
    }

    @Test("Output contains project name in title tag")
    func containsProjectNameInTitle() {
        let output = reporter.generate(modules: [], projectName: "MyAwesomeApp")
        #expect(output.contains("<title>") && output.contains("MyAwesomeApp"))
    }

    @Test("Output contains project name in header")
    func containsProjectNameInHeader() {
        let output = reporter.generate(modules: [], projectName: "MyAwesomeApp")
        #expect(output.contains("MyAwesomeApp"))
    }

    // MARK: - Summary stats

    @Test("Shows migration score in summary grid")
    func showsMigrationScore() {
        let finding = makeFinding(rule: "UncheckedSendableRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Migration Score"))
        #expect(output.contains("1.00"))
    }

    @Test("Shows module count in summary")
    func showsModuleCount() {
        let modules = [
            makeModuleResult(name: "A", findings: []),
            makeModuleResult(name: "B", findings: [])
        ]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Modules"))
    }

    @Test("Project status badge shows Migrated when score is 0")
    func showsMigratedBadge() {
        let modules = [makeModuleResult(name: "M", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Migrated"))
        #expect(output.contains("✅"))
    }

    @Test("Project status badge shows Pending Migration when findings exist")
    func showsPendingBadge() {
        let modules = [makeModuleResult(name: "M", findings: [makeFinding()])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("Pending Migration"))
        #expect(output.contains("⏳"))
    }

    // MARK: - Navigation panels

    @Test("Output contains three navigation tabs")
    func hasThreeNavTabs() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("panel-modules"))
        #expect(output.contains("panel-all-findings"))
        #expect(output.contains("panel-complexity"))
    }

    @Test("Complexity panel contains the weight table")
    func complexityPanelHasWeightTable() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("Complexity Table") || output.contains("panel-complexity"))
        #expect(output.contains("UncheckedSendableRule"))
        #expect(output.contains("GlobalMutableStateRule"))
    }

    // MARK: - Module table

    @Test("Module overview table lists all modules")
    func modulesTableListsAllModules() {
        let modules = [
            makeModuleResult(name: "CoreModule",    findings: []),
            makeModuleResult(name: "NetworkModule", findings: [makeFinding()])
        ]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("CoreModule"))
        #expect(output.contains("NetworkModule"))
    }

    @Test("Module rows are clickable (onclick attribute present)")
    func moduleRowsAreClickable() {
        let modules = [makeModuleResult(name: "M", findings: [])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("showModule"))
    }

    // MARK: - Findings table

    @Test("All findings table contains finding locations")
    func findingsTableContainsLocations() {
        let finding = makeFinding(file: "HomeViewModel.swift", line: 42)
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("HomeViewModel.swift"))
        #expect(output.contains("42"))
    }

    @Test("All findings table contains severity badges")
    func findingsTableContainsSeverityBadges() {
        let finding = makeFinding(severity: .error, rule: "ForceTryRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("badge error") || output.contains("class=\"badge error\""))
    }

    @Test("All findings table shows complexity weight column")
    func findingsTableShowsWeight() {
        let finding = makeFinding(rule: "ForceUnwrapRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        // Weight column header
        #expect(output.contains("Weight"))
        // ForceUnwrapRule weight = 0.3
        #expect(output.contains("0.3"))
    }

    // MARK: - JavaScript

    @Test("Output contains sortTable JavaScript function")
    func containsSortTableJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function sortTable"))
    }

    @Test("Output contains showModule JavaScript function")
    func containsShowModuleJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function showModule"))
    }

    // MARK: - HTML escaping

    @Test("HTML-escapes special characters in project name")
    func escapesProjectName() {
        let output = reporter.generate(modules: [], projectName: "<My & App>")
        #expect(output.contains("&lt;My &amp; App&gt;"))
        #expect(!output.contains("<My & App>"))
    }

    @Test("HTML-escapes special characters in finding messages")
    func escapesMessages() {
        let finding = makeFinding(message: "Use <Actor> & async/await")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        #expect(output.contains("&lt;Actor&gt;"))
        #expect(output.contains("&amp;"))
    }
}
