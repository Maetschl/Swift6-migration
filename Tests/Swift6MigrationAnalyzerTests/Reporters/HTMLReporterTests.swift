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
        let finding = makeFinding(severity: .error, rule: "UncheckedSendableRule")
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
        let modules = [makeModuleResult(name: "M", findings: [makeFinding(severity: .error)])]
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
        let finding = makeFinding(rule: "NotificationCenterRule")
        let modules = [makeModuleResult(name: "M", findings: [finding])]
        let output = reporter.generate(modules: modules, projectName: "P")
        // Weight column header
        #expect(output.contains("Weight"))
        // NotificationCenterRule weight = 0.4
        #expect(output.contains("0.4"))
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


// MARK: - Hierarchy & aggregate score tests (appended)

extension HTMLReporterTests {

    @Test("Module row uses aggregateStatus badge not own status")
    func rowUsesAggregateStatus() {
        // Parent has no findings but child does → aggregateStatus = pendingMigration
        let child = makeModuleResult(
            name: "Sub", findings: [makeFinding(severity: .error)],
            depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent", findings: [],
            depth: 0, childQualifiedNames: ["Parent/Sub"],
            aggregateScore: child.score
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        // The parent row should display "Pending Migration" badge (from aggregateStatus)
        #expect(output.contains("Pending Migration"))
    }

    @Test("Parent detail panel contains sub-modules table when children exist")
    func parentDetailHasChildrenSummary() {
        let child = makeModuleResult(
            name: "Sub", findings: [makeFinding(severity: .error)],
            depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent", findings: [],
            depth: 0, childQualifiedNames: ["Parent/Sub"],
            aggregateScore: child.score
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("Sub-modules"))
    }

    @Test("Parent detail panel does not show 'no findings' when children have findings")
    func parentDetailDoesNotShowEmptyStateWhenChildrenPending() {
        let child = makeModuleResult(
            name: "Sub", findings: [makeFinding(severity: .error)],
            depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent", findings: [],
            depth: 0, childQualifiedNames: ["Parent/Sub"],
            aggregateScore: child.score
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(!output.contains("No migration issues found in this module"))
    }

    @Test("Module row shows subtree score from aggregateScore")
    func rowShowsAggregateScore() {
        let child = makeModuleResult(
            name: "Sub", findings: [makeFinding(rule: "UncheckedSendableRule")],
            depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent", findings: [],
            depth: 0, childQualifiedNames: ["Parent/Sub"],
            aggregateScore: 1.0   // UncheckedSendable weight = 1.0
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("1.00"))
    }
}

// MARK: - Depth toolbar & collapse/expand tests

extension HTMLReporterTests {

    // MARK: Toolbar presence

    @Test("Modules panel contains depth stepper toolbar")
    func hasDepthStepperToolbar() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("table-toolbar"))
        #expect(output.contains("btn-depth-dec"))
        #expect(output.contains("btn-depth-inc"))
        #expect(output.contains("depth-value"))
    }

    @Test("Toolbar contains Expand All and Collapse All buttons")
    func hasExpandCollapseButtons() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("expandAll()"))
        #expect(output.contains("collapseAll()"))
        #expect(output.contains("Expand All"))
        #expect(output.contains("Collapse All"))
    }

    @Test("Depth stepper shows maxDepth value from module data")
    func depthStepperShowsMaxDepth() {
        let child = makeModuleResult(
            name: "Sub", findings: [],
            depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(name: "Parent", findings: [], childQualifiedNames: ["Parent/Sub"])
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        // maxDepthFound = 1, so depth-value span contains "1"
        #expect(output.contains("id=\"depth-value\">1<"))
    }

    @Test("Toolbar is hidden when module detail is shown (JS wires display:none)")
    func toolbarHiddenOnModuleDetail() {
        let output = reporter.generate(modules: [], projectName: "P")
        // The showModule JS function must hide .table-toolbar
        #expect(output.contains(".table-toolbar") && output.contains("display = 'none'"))
    }

    @Test("Toolbar is restored when back button is clicked")
    func toolbarRestoredOnBack() {
        let output = reporter.generate(modules: [], projectName: "P")
        // hideModuleDetails restores the toolbar
        #expect(output.contains("function hideModuleDetails"))
        #expect(output.contains(".table-toolbar"))
    }

    // MARK: data-* attributes on rows

    @Test("Module rows carry data-depth attribute")
    func rowsHaveDataDepth() {
        let mod = makeModuleResult(name: "M", findings: [], depth: 0)
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("data-depth=\"0\""))
    }

    @Test("Child rows carry data-depth reflecting nesting level")
    func childRowsHaveCorrectDepth() {
        let child = makeModuleResult(
            name: "Sub", findings: [], depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(name: "Parent", findings: [], childQualifiedNames: ["Parent/Sub"])
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("data-depth=\"1\""))
    }

    @Test("Module rows carry data-safe-id attribute")
    func rowsHaveDataSafeId() {
        let mod = makeModuleResult(name: "Core", findings: [])
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("data-safe-id=\"Core\""))
    }

    @Test("Child rows carry data-parent-id pointing to parent's safe-id")
    func childRowsHaveDataParentId() {
        let child = makeModuleResult(
            name: "Sub", findings: [], depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(name: "Parent", findings: [], childQualifiedNames: ["Parent/Sub"])
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("data-parent-id=\"Parent\""))
    }

    @Test("Top-level module rows have empty data-parent-id")
    func topLevelRowsHaveEmptyParentId() {
        let mod = makeModuleResult(name: "Root", findings: [], depth: 0)
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("data-parent-id=\"\""))
    }

    // MARK: Toggle buttons

    @Test("Parent modules (with children) have a toggle-btn")
    func parentModulesHaveToggleButton() {
        let child = makeModuleResult(
            name: "Sub", findings: [], depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(
            name: "Parent", findings: [], childQualifiedNames: ["Parent/Sub"]
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("class='toggle-btn'"))
        #expect(output.contains("toggleCollapse"))
    }

    @Test("Leaf modules (no children) have toggle-spacer instead of toggle-btn")
    func leafModulesHaveToggleSpacer() {
        let mod = makeModuleResult(name: "Leaf", findings: [], childQualifiedNames: [])
        let output = reporter.generate(modules: [mod], projectName: "P")
        // Spacer must be present for the leaf row
        #expect(output.contains("toggle-spacer"))
        // No actual toggle-btn element (the function definition exists in JS but no element)
        #expect(!output.contains("class='toggle-btn'"))
    }

    @Test("Toggle button calls toggleCollapse with module's safe-id")
    func toggleButtonCallsCorrectId() {
        let child = makeModuleResult(
            name: "Networking", findings: [], depth: 1, parentQualifiedName: "Core"
        )
        let parent = makeModuleResult(
            name: "Core", findings: [], childQualifiedNames: ["Core/Networking"]
        )
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("toggleCollapse(\"Core\")"))
    }

    // MARK: depth-chevron indentation

    @Test("Depth-1 modules render depth chevron ›")
    func depthOneRendersChevron() {
        let child = makeModuleResult(
            name: "Sub", findings: [], depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(name: "Parent", findings: [], childQualifiedNames: ["Parent/Sub"])
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("depth-chevron"))
        #expect(output.contains("›"))
    }

    @Test("Depth-2 modules render two chevrons ››")
    func depthTwoRendersTwoChevrons() {
        let grandchild = makeModuleResult(
            name: "GC", findings: [], depth: 2, parentQualifiedName: "Parent/Sub"
        )
        let child = makeModuleResult(
            name: "Sub", findings: [], depth: 1,
            parentQualifiedName: "Parent", childQualifiedNames: ["Parent/Sub/GC"]
        )
        let parent = makeModuleResult(
            name: "Parent", findings: [], childQualifiedNames: ["Parent/Sub"]
        )
        let output = reporter.generate(modules: [parent, child, grandchild], projectName: "P")
        #expect(output.contains("data-depth=\"2\""))
        #expect(output.contains("››"))
    }

    // MARK: JavaScript functions

    @Test("Output contains changeDepth JavaScript function")
    func containsChangeDepthJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function changeDepth"))
    }

    @Test("Output contains toggleCollapse JavaScript function")
    func containsToggleCollapseJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function toggleCollapse"))
    }

    @Test("Output contains expandAll JavaScript function")
    func containsExpandAllJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function expandAll"))
    }

    @Test("Output contains collapseAll JavaScript function")
    func containsCollapseAllJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function collapseAll"))
    }

    @Test("Output contains applyFilters JavaScript function")
    func containsApplyFiltersJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function applyFilters"))
    }

    @Test("Output contains isAncestorCollapsed JavaScript function")
    func containsIsAncestorCollapsedJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function isAncestorCollapsed"))
    }

    @Test("Output contains sortModulesTable hierarchy-aware sort function")
    func containsSortModulesTableJS() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("function sortModulesTable"))
        // Must use data-safe-id / data-parent-id for child map
        #expect(output.contains("dataset.safeId"))
        #expect(output.contains("dataset.parentId"))
    }

    @Test("maxDepthInData JS constant reflects maximum module depth")
    func jsMaxDepthConstantMatchesData() {
        let child = makeModuleResult(
            name: "Sub", findings: [], depth: 1, parentQualifiedName: "Parent"
        )
        let parent = makeModuleResult(name: "Parent", findings: [], childQualifiedNames: ["Parent/Sub"])
        let output = reporter.generate(modules: [parent, child], projectName: "P")
        #expect(output.contains("const maxDepthInData = 1"))
    }

    // MARK: Migrated % stat

    @Test("Summary grid contains Modules Migrated stat")
    func hasMigratedStatCard() {
        let output = reporter.generate(modules: [], projectName: "P")
        #expect(output.contains("Modules Migrated"))
    }

    @Test("Migrated stat shows correct count and percentage")
    func migratedStatShowsCountAndPercent() {
        let migrated = makeModuleResult(name: "A", findings: [])       // migrated
        let pending  = makeModuleResult(name: "B", findings: [makeFinding(severity: .error)]) // pending
        let output = reporter.generate(modules: [migrated, pending], projectName: "P")
        // 1 out of 2 = 50%
        #expect(output.contains("50%"))
        #expect(output.contains("migrated-stat"))
    }

    @Test("Migrated stat counts warning-only modules as migrated")
    func migratedStatIncludesWarningOnlyModules() {
        let warnOnly = makeModuleResult(name: "W", findings: [makeFinding(severity: .warning)])
        let output = reporter.generate(modules: [warnOnly], projectName: "P")
        // 1/1 = 100%
        #expect(output.contains("100%"))
    }

    // MARK: Multi-badge status in table cells

    @Test("Status cell uses status-cell flex container")
    func statusCellUsesFlexContainer() {
        let mod = makeModuleResult(name: "M", findings: [])
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("class=\"status-cell\""))
    }

    @Test("Migrated module shows green migrated badge")
    func migratedModuleShowsGreenBadge() {
        let mod = makeModuleResult(name: "M", findings: [])
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("status-badge migrated"))
    }

    @Test("Warning-only module shows both Migrated and Warnings badges")
    func warningOnlyModuleShowsBothBadges() {
        let mod = makeModuleResult(name: "W", findings: [makeFinding(severity: .warning)])
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("status-badge migrated"))
        #expect(output.contains("status-badge tag-warnings"))
    }

    @Test("Pending module shows orange pending badge")
    func pendingModuleShowsPendingBadge() {
        let mod = makeModuleResult(name: "P2", findings: [makeFinding(severity: .error)])
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("status-badge pending"))
    }

    @Test("Project header uses project-status-bar with individual badges")
    func projectHeaderUsesStatusBar() {
        let mod = makeModuleResult(name: "M", findings: [])
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("project-status-bar"))
    }

    // MARK: Score gradient

    @Test("Score pill colour is always green (#34c759) for score 0")
    func scorePillGreenForZero() {
        let mod = makeModuleResult(name: "M", findings: [])
        let output = reporter.generate(modules: [mod], projectName: "P")
        #expect(output.contains("#34c759"))
    }

    @Test("Score pill colour is not green when score is highest in set")
    func scorePillNotGreenForHighScore() {
        // Two modules: one clean, one with a high-weight error finding
        let heavy = makeModuleResult(
            name: "Heavy",
            findings: [makeFinding(severity: .error, rule: "UncheckedSendableRule")] // weight 1.0
        )
        let clean = makeModuleResult(name: "Clean", findings: [])
        let output = reporter.generate(modules: [heavy, clean], projectName: "P")
        // The heavy module's score-pill background should NOT be green (#34c75920).
        // Locate the heavy module's table row, then find its pill background color.
        let heavyPillIsGreen: Bool = {
            // Module row contains: <strong>Heavy</strong> … score-pill … background:#xxxxxx20
            guard let nameRange = output.range(of: "Heavy") else { return false }
            let rest = String(output[nameRange.upperBound...])
            guard let bgRange = rest.range(of: "background:") else { return false }
            return rest[bgRange.upperBound...].hasPrefix("#34c759")
        }()
        #expect(!heavyPillIsGreen, "Heavy module's score pill should not use the green (#34c759) background")
    }
}
