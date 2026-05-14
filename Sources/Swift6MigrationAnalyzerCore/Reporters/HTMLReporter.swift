import Foundation

public struct HTMLReporter: Reporter {
    public init() {}

    // MARK: - Module-aware dashboard

    public func generate(modules: [ModuleResult], projectName: String) -> String {
        let allFindings   = modules.flatMap { $0.findings }
        let projectScore  = modules.filter { $0.depth == 0 }.reduce(0.0) { $0 + $1.aggregateScore }
        let maxDepthFound = modules.map(\.depth).max() ?? 0

        // Common path prefix for trimming absolute paths → project-relative display
        let rootPath: String = {
            let paths = modules.map { $0.path }
            guard !paths.isEmpty else { return "" }
            var parts = paths[0].components(separatedBy: "/")
            for p in paths.dropFirst() {
                let other = p.components(separatedBy: "/")
                var i = 0
                while i < parts.count && i < other.count && parts[i] == other[i] { i += 1 }
                parts = Array(parts.prefix(i))
            }
            return parts.joined(separator: "/")
        }()
        let trimPath: (String) -> String = { path in
            guard !rootPath.isEmpty, path.hasPrefix(rootPath) else { return path }
            var rel = String(path.dropFirst(rootPath.count))
            if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
            return rel.isEmpty ? path : rel
        }

        // Composite project status
        let hasProjectWarnings = allFindings.contains { $0.severity == .warning || $0.severity == .info }
        let projectStatus: MigrationStatus = {
            var tags: Set<MigrationTag> = projectScore == 0 ? [.migrated] : [.pendingMigration]
            if hasProjectWarnings { tags.insert(.warnings) }
            return MigrationStatus(tags)
        }()

        let totalErrors   = allFindings.filter { $0.severity == .error }.count
        let totalWarnings = allFindings.filter { $0.severity == .warning }.count
        let totalFiles    = modules.reduce(0) { $0 + $1.fileCount }
        let totalLines    = modules.reduce(0) { $0 + $1.totalLinesOfCode }

        // Migrated modules totalizer (includes "Migrated · Warnings")
        let migratedCount = modules.filter { $0.aggregateStatus.isMigrated }.count
        let migratedPct   = modules.isEmpty ? 0
            : Int((Double(migratedCount) / Double(modules.count) * 100).rounded())

        // Score colour gradient — 0 = green, top-20% threshold = red
        let positiveScores = modules.map { $0.aggregateScore }.filter { $0 > 0 }.sorted()
        let scoreThreshold: Double = {
            guard !positiveScores.isEmpty else { return 1 }
            let idx = max(0, Int((Double(positiveScores.count) * 0.8).rounded(.up)) - 1)
            return positiveScores[min(idx, positiveScores.count - 1)]
        }()

        let totalActors    = modules.reduce(0) { $0 + $1.migrationIndicators.actorDeclarationCount }
        let totalMainActor = modules.reduce(0) { $0 + $1.migrationIndicators.mainActorAnnotationCount }
        let totalAsync     = modules.reduce(0) { $0 + $1.migrationIndicators.asyncFunctionCount }
        let totalSendable  = modules.reduce(0) { $0 + $1.migrationIndicators.sendableConformanceCount }

        let moduleRows = modules.map { module -> String in
            let sc           = scoreGradientColor(module.aggregateScore, threshold: scoreThreshold)
            let ind          = module.aggregateMigrationIndicators
            let aggrScore    = String(format: "%.2f", module.aggregateScore)
            let ownScoreNote = module.aggregateScore != module.score
                ? "<small style='color:#888'> (own: \(String(format: "%.2f", module.score)))</small>"
                : ""
            let safeId       = jsId(module.qualifiedName)
            let parentSafeId = module.parentQualifiedName.map { jsId($0) } ?? ""
            let hasChildren  = !module.childQualifiedNames.isEmpty
            let toggleBtn    = hasChildren
                ? "<button class='toggle-btn' onclick='event.stopPropagation();toggleCollapse(\"\(safeId)\")' title='Collapse sub-modules'>&#9660;</button>"
                : "<span class='toggle-spacer'></span>"
            let depthChevrons = module.depth > 0
                ? "<span class='depth-chevron'>\(String(repeating: "›", count: module.depth))</span>"
                : ""
            let paddingLeft = 8 + module.depth * 20
            let findingsBadge = module.aggregateFindings > module.findings.count
                ? "\(module.aggregateFindings)<small style='color:#aaa'> (\(module.findings.count) own)</small>"
                : "\(module.findings.count)"
            return """
            <tr class="module-row" data-depth="\(module.depth)" data-safe-id="\(safeId)" data-parent-id="\(parentSafeId)" onclick="showModule('\(safeId)')" style="cursor:pointer">
              <td style="padding-left:\(paddingLeft)px">\(depthChevrons)\(toggleBtn)<strong>\(escapeHTML(module.name))</strong></td>
              <td><div class="status-cell">\(module.aggregateStatus.badgesHTML)</div></td>
              <td><span class="score-pill" style="background:\(sc)20;color:\(sc)">\(aggrScore)</span>\(ownScoreNote)</td>
              <td>\(module.fileCount)</td>
              <td>\(findingsBadge)</td>
              <td class="indicator">\(ind.actorDeclarationCount)</td>
              <td class="indicator">\(ind.mainActorAnnotationCount)</td>
              <td class="indicator">\(ind.asyncFunctionCount)</td>
            </tr>
            """
        }.joined()

        let moduleDetailSections = modules.map { module -> String in
            let ind    = module.migrationIndicators
            let safeId = jsId(module.qualifiedName)
            let indicatorBar = """
            <div class="indicator-bar">
              <span class="ind-chip actor">\(ind.actorDeclarationCount) actors</span>
              <span class="ind-chip mainactor">\(ind.mainActorAnnotationCount) @MainActor</span>
              <span class="ind-chip async">\(ind.asyncFunctionCount) async</span>
              <span class="ind-chip sendable">\(ind.sendableConformanceCount) Sendable</span>
            </div>
            """
            let childrenSummary: String
            if !module.childQualifiedNames.isEmpty {
                let childRows = module.childQualifiedNames.compactMap { cName -> String? in
                    guard let child = modules.first(where: { $0.qualifiedName == cName }) else { return nil }
                    let cc = scoreGradientColor(child.aggregateScore, threshold: scoreThreshold)
                    return "<tr><td><strong>\(escapeHTML(child.name))</strong></td><td><div class='status-cell'>\(child.aggregateStatus.badgesHTML)</div></td><td><span class='score-pill' style='background:\(cc)20;color:\(cc)'>\(String(format: "%.2f", child.aggregateScore))</span></td><td>\(child.findings.count)</td></tr>"
                }.joined(separator: "\n")
                childrenSummary = """
                <h3>Sub-modules</h3>
                <table class="findings-table" style="width:100%">
                  <thead><tr><th>Module</th><th>Status</th><th>Subtree Score</th><th>Findings</th></tr></thead>
                  <tbody>\(childRows)</tbody>
                </table>
                """
            } else {
                childrenSummary = ""
            }
            if module.findings.isEmpty {
                let emptyMsg = module.childQualifiedNames.isEmpty
                    ? "<p class=\"empty-state\">&#x2705; No migration issues found in this module.</p>"
                    : "<p class=\"empty-state\">No direct findings — see sub-modules above.</p>"
                return """
                <div id="module-\(safeId)" class="module-detail" style="display:none">
                  <div class="module-header">
                    <h2>\(module.aggregateStatus.icon) \(escapeHTML(module.qualifiedName))</h2>
                    <div class="status-cell">\(module.aggregateStatus.badgesHTML)</div>
                    <span class="score-pill-lg">Subtree Score \(String(format: "%.2f", module.aggregateScore))</span>
                    <span class="meta">\(module.fileCount) files &middot; \(module.totalLinesOfCode) lines</span>
                  </div>
                  \(indicatorBar)\(childrenSummary)\(emptyMsg)
                </div>
                """
            }
            let byRule = Dictionary(grouping: module.findings, by: \.rule)
            let ruleCards = byRule.keys.sorted().map { ruleName -> String in
                let ruleFindings = byRule[ruleName] ?? []
                let weight = FindingComplexity.weight(for: ruleName)
                let errorCount   = ruleFindings.filter { $0.severity == .error }.count
                let warningCount = ruleFindings.filter { $0.severity == .warning }.count
                let items = ruleFindings.map { f -> String in
                    let relFile = trimPath(f.file)
                    let loc = "\(relFile):\(f.line)"
                    return "<li data-severity=\"\(f.severity.rawValue)\"><span class=\"badge \(f.severity.htmlClass)\">\(f.severity.rawValue)</span> <code>\(escapeHTML(loc))</code> &mdash; \(escapeHTML(f.message))</li>"
                }.joined(separator: "\n")
                let wandId = jsId(module.qualifiedName + ruleName)
                let severityBadges = (errorCount > 0 ? "<span class='badge error'>\(errorCount) error\(errorCount == 1 ? "" : "s")</span> " : "")
                                   + (warningCount > 0 ? "<span class='badge warning'>\(warningCount) warning\(warningCount == 1 ? "" : "s")</span>" : "")
                return """
                <div class="rule-card">
                  <div class="rule-header">
                    <span class="rule-name">\(escapeHTML(ruleName))</span>
                    <span class="weight-pill">weight \(weight)</span>
                    \(severityBadges)
                    <span class="count">\(ruleFindings.count)</span>
                    <button class="wand-btn" onclick="toggleWand('\(wandId)')" title="How to fix this rule">&#x1FA84;</button>
                  </div>
                  <div id="wand-\(wandId)" class="wand-panel" style="display:none">
                    <p class="wand-rule-link">&#x1F4C4; <strong>\(escapeHTML(ruleName))</strong> — see full documentation in <code>Docs/Rules/\(escapeHTML(ruleName)).md</code></p>
                  </div>
                  <div class="finding-filter-bar">
                    <button class="filter-btn active" data-filter="all"     onclick="filterFindings(this, '\(wandId)')">All (\(ruleFindings.count))</button>
                    \(errorCount   > 0 ? "<button class='filter-btn' data-filter='error'   onclick='filterFindings(this, \"\(wandId)\")'>\u{1F534} Errors (\(errorCount))</button>" : "")
                    \(warningCount > 0 ? "<button class='filter-btn' data-filter='warning' onclick='filterFindings(this, \"\(wandId)\")'>\u{26A0}\u{FE0F} Warnings (\(warningCount))</button>" : "")
                  </div>
                  <ul id="findings-\(wandId)">\(items)</ul>
                </div>
                """
            }.joined()
            let scoreLabel = module.aggregateScore != module.score
                ? "Own Score \(String(format: "%.2f", module.score)) &middot; Subtree \(String(format: "%.2f", module.aggregateScore))"
                : "Score \(String(format: "%.2f", module.score))"
            return """
            <div id="module-\(safeId)" class="module-detail" style="display:none">
              <div class="module-header">
                <h2>\(module.aggregateStatus.icon) \(escapeHTML(module.qualifiedName))</h2>
                <div class="status-cell">\(module.aggregateStatus.badgesHTML)</div>
                <span class="score-pill-lg">\(scoreLabel)</span>
                <span class="meta">\(module.fileCount) files &middot; \(module.totalLinesOfCode) lines</span>
              </div>
              \(indicatorBar)\(childrenSummary)\(ruleCards)
            </div>
            """
        }.joined()

        let allRows = allFindings.map { f -> String in
            let relFile = trimPath(f.file)
            return """
            <tr class="\(f.severity.htmlClass)">
              <td>\(escapeHTML(relFile)):\(f.line)</td>
              <td><span class="badge \(f.severity.htmlClass)">\(f.severity.rawValue.uppercased())</span></td>
              <td>\(escapeHTML(f.rule))</td>
              <td>\(String(format: "%.1f", FindingComplexity.weight(for: f.rule)))</td>
              <td>\(escapeHTML(f.message))</td>
            </tr>
            """
        }.joined()

        let weightRows = FindingComplexity.weightTable.map { entry -> String in
            "<tr><td><code>\(escapeHTML(entry.rule))</code></td><td><strong>\(entry.weight)</strong></td><td>\(escapeHTML(entry.rationale))</td></tr>"
        }.joined()

        let topModules = modules.filter { $0.depth == 0 }.sorted { $0.aggregateScore > $1.aggregateScore }
        let maxBarScore = topModules.map { $0.aggregateScore }.first ?? 1.0
        let barScale = maxBarScore > 0 ? maxBarScore : 1.0
        let chartRows = topModules.map { module -> String in
            let score    = module.aggregateScore
            let safeId   = jsId(module.qualifiedName)
            let color    = scoreBarColor(score)
            let widthPct = min(100.0, (score / barScale) * 100.0)
            if score == 0 {
                return """
                <div class="chart-row" onclick="showPanel('modules');showModule('\(safeId)')">
                  <span class="bar-label">\(escapeHTML(module.name))</span>
                  <span class="bar-zero">&#x2705;</span>
                  <span class="bar-value bar-value-zero">0.00</span>
                </div>
                """
            } else {
                return """
                <div class="chart-row" onclick="showPanel('modules');showModule('\(safeId)')">
                  <span class="bar-label">\(escapeHTML(module.name))</span>
                  <div class="bar-track"><div class="bar-fill" style="width:\(String(format:"%.2f",widthPct))%;background:\(color)"></div></div>
                  <span class="bar-value" style="color:\(color)">\(String(format:"%.2f",score))</span>
                </div>
                """
            }
        }.joined()

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Swift 6 Migration &mdash; \(escapeHTML(projectName))</title>
        <style>
          *{box-sizing:border-box;margin:0;padding:0}
          body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f5f5f7;color:#1d1d1f}
          header{background:#1d1d1f;color:#fff;padding:2rem 2.5rem}
          header h1{font-size:1.8rem}
          header .subtitle{opacity:.65;margin-top:.4rem;font-size:.95rem}
          .project-status-bar{display:inline-flex;align-items:center;gap:.4rem;margin-top:.75rem;flex-wrap:wrap}
          .summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:1rem;padding:1.5rem 2.5rem}
          .stat{background:#fff;border-radius:14px;padding:1rem 1.25rem;box-shadow:0 1px 4px rgba(0,0,0,.08)}
          .stat .num{font-size:1.8rem;font-weight:700}
          .stat .lbl{color:#6e6e73;font-size:.78rem;margin-top:.2rem}
          .stat.score .num{color:#ff9500}
          .stat.errors .num{color:#ff3b30}
          .stat.warnings-stat .num{color:#ff9500}
          .stat.migrated-stat .num{color:#34c759}
          .stat.migrated-stat .pct{font-size:.95rem;font-weight:500;color:#34c759;margin-left:.2rem}
          .indicators-strip{display:flex;gap:.75rem;padding:0 2.5rem 1.25rem;flex-wrap:wrap}
          .ind-stat{background:#f0fdf4;border:1px solid #bbf7d0;border-radius:10px;padding:.5rem .9rem;font-size:.85rem}
          .ind-stat strong{color:#16a34a;font-size:1.1rem;margin-right:.3rem}
          nav{display:flex;gap:.5rem;padding:0 2.5rem 1rem;flex-wrap:wrap}
          nav button{background:#fff;border:1.5px solid #d1d1d6;border-radius:8px;padding:.45rem .9rem;font-size:.85rem;cursor:pointer;transition:all .15s}
          nav button.active,nav button:hover{background:#1d1d1f;color:#fff;border-color:#1d1d1f}
          .panel{display:none;padding:0 2.5rem 2.5rem}
          .panel.active{display:block}
          .table-toolbar{display:flex;align-items:center;gap:.5rem;margin-bottom:.75rem;flex-wrap:wrap}
          .toolbar-label{font-size:.82rem;color:#6e6e73;font-weight:600}
          .stepper-btn{background:#fff;border:1.5px solid #d1d1d6;border-radius:8px;padding:.28rem .7rem;font-size:.9rem;font-weight:700;cursor:pointer;transition:all .15s;min-width:2.1rem;line-height:1.4}
          .stepper-btn:hover{background:#1d1d1f;color:#fff;border-color:#1d1d1f}
          .stepper-btn:disabled{opacity:.35;cursor:default;pointer-events:none}
          #depth-value{font-size:.95rem;font-weight:700;min-width:1.6rem;text-align:center;display:inline-block;background:#fff;border:1.5px solid #d1d1d6;border-radius:8px;padding:.28rem .5rem}
          .toolbar-sep{width:1px;height:1.6rem;background:#d1d1d6;margin:0 .15rem}
          .toggle-btn{background:none;border:none;cursor:pointer;font-size:.68rem;color:#bbb;padding:0;margin-right:4px;line-height:1;vertical-align:middle;transition:color .12s;display:inline-block;width:14px}
          .toggle-btn:hover{color:#1d1d1f}
          .toggle-spacer{display:inline-block;width:18px}
          .depth-chevron{color:#ccc;margin-right:4px;font-size:.8rem;user-select:none;letter-spacing:1px}
          .module-detail{display:none;margin-bottom:1.5rem}
          .module-header{display:flex;align-items:center;gap:.75rem;flex-wrap:wrap;margin-bottom:.75rem}
          .module-header h2{font-size:1.25rem}
          .meta{color:#6e6e73;font-size:.85rem}
          .indicator-bar{display:flex;gap:.5rem;flex-wrap:wrap;margin-bottom:1rem}
          .ind-chip{border-radius:999px;padding:.2rem .65rem;font-size:.76rem;font-weight:600}
          .ind-chip.actor{background:#dbeafe;color:#1d4ed8}
          .ind-chip.mainactor{background:#fce7f3;color:#9d174d}
          .ind-chip.async{background:#dcfce7;color:#166534}
          .ind-chip.sendable{background:#f3e8ff;color:#6b21a8}
          .status-cell{display:flex;flex-wrap:wrap;gap:.3rem;align-items:center}
          .status-badge{display:inline-block;border-radius:999px;padding:.2rem .7rem;font-size:.8rem;font-weight:600;white-space:nowrap}
          .status-badge.migrated{background:#34c75922;color:#34c759}
          .status-badge.pending{background:#ff950022;color:#ff9500}
          .status-badge.tag-warnings{background:#f5a62322;color:#b45309}
          .score-pill{display:inline-block;border-radius:999px;padding:.15rem .6rem;font-size:.8rem;font-weight:700}
          .score-pill-lg{display:inline-block;border-radius:999px;padding:.3rem .8rem;font-size:.9rem;font-weight:700;background:#ff950022;color:#ff9500}
          .rule-card{background:#fff;border-radius:12px;padding:1rem 1.25rem;margin-bottom:.75rem;box-shadow:0 1px 4px rgba(0,0,0,.08)}
          .rule-header{display:flex;align-items:center;gap:.6rem;margin-bottom:.6rem;flex-wrap:wrap}
          .rule-name{font-weight:600;font-size:.95rem}
          .weight-pill{background:#007aff18;color:#007aff;border-radius:999px;padding:.1rem .5rem;font-size:.75rem;font-weight:600}
          .count{background:#e5e5ea;border-radius:999px;padding:.1rem .5rem;font-size:.8rem;font-weight:600}
          .rule-card ul{list-style:none}
          .rule-card li{padding:.35rem 0;border-bottom:1px solid #f2f2f7;font-size:.88rem}
          .rule-card li:last-child{border-bottom:none}
          .badge{display:inline-block;border-radius:4px;padding:.1rem .4rem;font-size:.72rem;font-weight:700;text-transform:uppercase}
          .badge.error{background:#ffe5e5;color:#ff3b30}
          .badge.warning{background:#fff3e0;color:#ff9500}
          .badge.info{background:#e5f0ff;color:#007aff}
          .indicator{color:#16a34a;font-weight:600}
          table{width:100%;border-collapse:collapse;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08)}
          th{background:#f2f2f7;padding:.7rem 1rem;text-align:left;font-size:.82rem;cursor:pointer;user-select:none}
          th:hover{background:#e5e5ea}
          td{padding:.6rem 1rem;font-size:.85rem;border-bottom:1px solid #f2f2f7}
          tr:last-child td{border-bottom:none}
          tr.error{background:#fff8f8}
          tr.warning{background:#fffcf5}
          h2.section-title{font-size:1.1rem;margin:.5rem 0 .75rem}
          code{font-family:"SF Mono",monospace;font-size:.83em}
          .empty-state{color:#6e6e73;padding:1.5rem;text-align:center;background:#fff;border-radius:12px}
          .back-btn{background:none;border:none;color:#007aff;font-size:.9rem;cursor:pointer;padding:.4rem 0;margin-bottom:1rem}
          .back-btn:hover{text-decoration:underline}
          .finding-filter-bar{display:flex;gap:.4rem;margin:.5rem 0 .5rem;flex-wrap:wrap}
          .filter-btn{background:#f2f2f7;border:1.5px solid #d1d1d6;border-radius:999px;padding:.18rem .65rem;font-size:.75rem;font-weight:600;cursor:pointer;transition:all .15s}
          .filter-btn.active,.filter-btn:hover{background:#1d1d1f;color:#fff;border-color:#1d1d1f}
          .wand-btn{background:none;border:none;font-size:1rem;cursor:pointer;padding:0 .2rem;opacity:.5;transition:opacity .15s;vertical-align:middle}
          .wand-btn:hover{opacity:1}
          .wand-panel{background:#f0f7ff;border:1px solid #bfdbfe;border-radius:10px;padding:.75rem 1rem;margin-bottom:.5rem;font-size:.85rem}
          .wand-rule-link{color:#1d4ed8}
          .wand-panel code{background:#dbeafe;padding:.1rem .3rem;border-radius:4px;font-size:.8rem}
          .chart-list{display:flex;flex-direction:column;gap:.55rem;max-width:900px}
          .chart-row{display:flex;align-items:center;gap:.75rem;cursor:pointer;border-radius:10px;padding:.45rem .6rem;transition:background .12s}
          .chart-row:hover{background:#e8e8ed}
          .bar-label{font-size:.88rem;font-weight:600;min-width:160px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex-shrink:0}
          .bar-track{flex:1;background:#e5e5ea;border-radius:999px;height:22px;overflow:hidden;min-width:60px}
          .bar-fill{height:100%;border-radius:999px;transition:width .4s ease}
          .bar-value{font-size:.82rem;font-weight:700;min-width:52px;text-align:right;flex-shrink:0}
          .bar-zero{font-size:1.1rem;line-height:22px}
          .bar-value-zero{color:#34c759}
        </style>
        </head>
        <body>
        <header>
          <h1>&#x1F50D; Swift 6 Migration Report</h1>
          <div class="subtitle">\(escapeHTML(projectName)) &middot; Generated \(Date().formatted())</div>
          <div class="project-status-bar">\(projectStatus.badgesHTML)</div>
        </header>

        <div class="summary-grid">
          <div class="stat score"><div class="num">\(String(format: "%.2f", projectScore))</div><div class="lbl">Migration Score</div></div>
          <div class="stat migrated-stat"><div class="num">\(migratedCount)<span class="pct">(\(migratedPct)%)</span></div><div class="lbl">Modules Migrated</div></div>
          <div class="stat"><div class="num">\(modules.count)</div><div class="lbl">Total Modules</div></div>
          <div class="stat errors"><div class="num">\(totalErrors)</div><div class="lbl">Errors</div></div>
          <div class="stat warnings-stat"><div class="num">\(totalWarnings)</div><div class="lbl">Warnings</div></div>
          <div class="stat"><div class="num">\(totalFiles)</div><div class="lbl">Files</div></div>
          <div class="stat"><div class="num">\(totalLines)</div><div class="lbl">Lines of Code</div></div>
        </div>

        <div class="indicators-strip">
          <div class="ind-stat"><strong>\(totalActors)</strong>actor declarations</div>
          <div class="ind-stat"><strong>\(totalMainActor)</strong>@MainActor annotations</div>
          <div class="ind-stat"><strong>\(totalAsync)</strong>async functions</div>
          <div class="ind-stat"><strong>\(totalSendable)</strong>Sendable conformances</div>
        </div>

        <nav>
          <button class="active" onclick="showPanel('modules')">Modules</button>
          <button onclick="showPanel('chart')">&#x1F4CA; Score Chart</button>
          <button onclick="showPanel('all-findings')">All Findings</button>
          <button onclick="showPanel('complexity')">Complexity Table</button>
        </nav>

        <div id="panel-modules" class="panel active">
          <div class="table-toolbar">
            <span class="toolbar-label">Depth:</span>
            <button class="stepper-btn" id="btn-depth-dec" onclick="changeDepth(-1)">&#8722;</button>
            <span id="depth-value">\(maxDepthFound)</span>
            <button class="stepper-btn" id="btn-depth-inc" onclick="changeDepth(1)">+</button>
            <div class="toolbar-sep"></div>
            <button class="stepper-btn" onclick="expandAll()">Expand All</button>
            <button class="stepper-btn" onclick="collapseAll()">Collapse All</button>
          </div>
          <h2 class="section-title">Module Overview</h2>
          <table id="modules-table">
            <thead>
              <tr>
                <th onclick="sortModulesTable(0)">Module &#x21D5;</th>
                <th onclick="sortModulesTable(1)">Status &#x21D5;</th>
                <th onclick="sortModulesTable(2)">Score &#x21D5;</th>
                <th onclick="sortModulesTable(3)">Files &#x21D5;</th>
                <th onclick="sortModulesTable(4)">Findings &#x21D5;</th>
                <th onclick="sortModulesTable(5)" title="actor declarations">Actors &#x21D5;</th>
                <th onclick="sortModulesTable(6)" title="@MainActor">@Main &#x21D5;</th>
                <th onclick="sortModulesTable(7)" title="async functions">async &#x21D5;</th>
              </tr>
            </thead>
            <tbody>\(moduleRows)</tbody>
          </table>
          <div id="module-details" style="margin-top:1.5rem;display:none">
            <button class="back-btn" onclick="hideModuleDetails()">&#8592; Back to module list</button>
            \(moduleDetailSections)
          </div>
        </div>

        <div id="panel-chart" class="panel">
          <div class="chart-list">
            \(chartRows)
          </div>
        </div>

        <div id="panel-all-findings" class="panel">
          <h2 class="section-title">All Findings (\(allFindings.count))</h2>
          <table id="findings-table">
            <thead>
              <tr>
                <th onclick="sortTable('findings-table',0)">Location &#x21D5;</th>
                <th onclick="sortTable('findings-table',1)">Severity &#x21D5;</th>
                <th onclick="sortTable('findings-table',2)">Rule &#x21D5;</th>
                <th onclick="sortTable('findings-table',3)">Weight &#x21D5;</th>
                <th>Message</th>
              </tr>
            </thead>
            <tbody>\(allRows)</tbody>
          </table>
        </div>

        <div id="panel-complexity" class="panel">
          <h2 class="section-title">Finding Complexity Weight Table</h2>
          <p style="color:#6e6e73;font-size:.9rem;margin-bottom:1rem">Score formula: <strong>SUM(finding &#xD7; complexity weight)</strong>. Higher score = more migration effort required.</p>
          <table>
            <thead><tr><th>Rule</th><th>Weight</th><th>Rationale</th></tr></thead>
            <tbody>\(weightRows)</tbody>
          </table>
        </div>

        <script>
        const maxDepthInData = \(maxDepthFound);
        let currentMaxDepth  = maxDepthInData;
        const collapsedSet   = new Set();

        function showPanel(id) {
          document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
          document.querySelectorAll('nav button').forEach(b => b.classList.remove('active'));
          document.getElementById('panel-' + id).classList.add('active');
          event.target.classList.add('active');
        }
        function showModule(safeId) {
          document.querySelectorAll('.module-detail').forEach(d => d.style.display = 'none');
          const detail = document.getElementById('module-' + safeId);
          if (detail) {
            detail.style.display = 'block';
            document.getElementById('module-details').style.display = 'block';
            document.getElementById('modules-table').style.display = 'none';
            document.querySelector('.table-toolbar').style.display = 'none';
            detail.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        }
        function hideModuleDetails() {
          document.getElementById('module-details').style.display = 'none';
          document.getElementById('modules-table').style.display = 'table';
          document.querySelector('.table-toolbar').style.display = '';
          document.querySelectorAll('.module-detail').forEach(d => d.style.display = 'none');
        }
        function changeDepth(delta) {
          currentMaxDepth = Math.max(0, Math.min(maxDepthInData, currentMaxDepth + delta));
          document.getElementById('depth-value').textContent = currentMaxDepth;
          document.getElementById('btn-depth-dec').disabled = currentMaxDepth === 0;
          document.getElementById('btn-depth-inc').disabled = currentMaxDepth === maxDepthInData;
          applyFilters();
        }
        function toggleCollapse(safeId) {
          if (collapsedSet.has(safeId)) { collapsedSet.delete(safeId); } else { collapsedSet.add(safeId); }
          const btn = document.querySelector('tr[data-safe-id="' + safeId + '"] .toggle-btn');
          if (btn) btn.innerHTML = collapsedSet.has(safeId) ? '&#9654;' : '&#9660;';
          applyFilters();
        }
        function expandAll() {
          collapsedSet.clear();
          document.querySelectorAll('.toggle-btn').forEach(b => b.innerHTML = '&#9660;');
          applyFilters();
        }
        function collapseAll() {
          document.querySelectorAll('tr.module-row').forEach(row => {
            if (row.querySelector('.toggle-btn')) collapsedSet.add(row.dataset.safeId);
          });
          document.querySelectorAll('.toggle-btn').forEach(b => b.innerHTML = '&#9654;');
          applyFilters();
        }
        function isAncestorCollapsed(parentId) {
          if (!parentId) return false;
          if (collapsedSet.has(parentId)) return true;
          const p = document.querySelector('tr[data-safe-id="' + parentId + '"]');
          return p ? isAncestorCollapsed(p.dataset.parentId || '') : false;
        }
        function applyFilters() {
          document.querySelectorAll('tr.module-row').forEach(row => {
            const depth  = parseInt(row.dataset.depth);
            const hidden = depth > currentMaxDepth || isAncestorCollapsed(row.dataset.parentId || '');
            row.style.display = hidden ? 'none' : '';
          });
        }
        function sortModulesTable(col) {
          const table = document.getElementById('modules-table');
          const tbody = table.tBodies[0];
          const rows  = Array.from(tbody.rows);
          const asc   = table.dataset.sortCol == col && table.dataset.sortDir === 'asc';
          const getValue = r => {
            const t = r.cells[col].innerText.trim().replace(/^[^A-Za-z0-9.]+/, '');
            const n = parseFloat(t);
            return isNaN(n) ? t : n;
          };
          const cmp = (a, b) => {
            const av = getValue(a), bv = getValue(b);
            if (typeof av === 'number' && typeof bv === 'number') return asc ? bv - av : av - bv;
            return asc ? String(bv).localeCompare(String(av)) : String(av).localeCompare(String(bv));
          };
          const childMap = {};
          rows.forEach(r => {
            const p = r.dataset.parentId;
            if (p) { childMap[p] = childMap[p] || []; childMap[p].push(r); }
          });
          const flatten = siblings => {
            const out = [];
            siblings.slice().sort(cmp).forEach(r => {
              out.push(r);
              flatten(childMap[r.dataset.safeId] || []).forEach(c => out.push(c));
            });
            return out;
          };
          flatten(rows.filter(r => !r.dataset.parentId)).forEach(r => tbody.appendChild(r));
          table.dataset.sortCol = col;
          table.dataset.sortDir = asc ? 'desc' : 'asc';
          applyFilters();
        }
        function sortTable(tableId, col) {
          const table = document.getElementById(tableId);
          const tbody = table.tBodies[0];
          const rows  = Array.from(tbody.rows);
          const asc   = table.dataset.sortCol == col && table.dataset.sortDir === 'asc';
          rows.sort((a, b) => {
            const at = a.cells[col].innerText.trim();
            const bt = b.cells[col].innerText.trim();
            const an = parseFloat(at), bn = parseFloat(bt);
            if (!isNaN(an) && !isNaN(bn)) return asc ? bn - an : an - bn;
            return asc ? bt.localeCompare(at) : at.localeCompare(bt);
          });
          rows.forEach(r => tbody.appendChild(r));
          table.dataset.sortCol = col;
          table.dataset.sortDir = asc ? 'desc' : 'asc';
        }
        function filterFindings(btn, wandId) {
          const filter = btn.dataset.filter;
          const ul = document.getElementById('findings-' + wandId);
          if (!ul) return;
          ul.querySelectorAll('li').forEach(li => {
            const sev = li.dataset.severity;
            li.style.display = (filter === 'all' || sev === filter) ? '' : 'none';
          });
          btn.closest('.finding-filter-bar').querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
          btn.classList.add('active');
        }
        function toggleWand(wandId) {
          const panel = document.getElementById('wand-' + wandId);
          if (panel) panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
        }
        document.getElementById('btn-depth-dec').disabled = currentMaxDepth === 0;
        document.getElementById('btn-depth-inc').disabled = currentMaxDepth === maxDepthInData;
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Flat report (fallback)

    public func generate(findings: [Finding]) -> String {
        let byRule = Dictionary(grouping: findings, by: \.rule)
        let totalErrors   = findings.filter { $0.severity == .error }.count
        let totalWarnings = findings.filter { $0.severity == .warning }.count
        var ruleCards = ""
        for ruleName in byRule.keys.sorted() {
            let rf = byRule[ruleName] ?? []
            ruleCards += "<div><h3>\(escapeHTML(ruleName)) (\(rf.count))</h3><ul>"
            for f in rf {
                ruleCards += "<li><span>\(f.severity.rawValue)</span> <code>\(escapeHTML(f.location))</code> &mdash; \(escapeHTML(f.message))</li>"
            }
            ruleCards += "</ul></div>"
        }
        return "<html><body><h1>Swift 6 Report</h1><p>Errors: \(totalErrors) &middot; Warnings: \(totalWarnings)</p>\(ruleCards)</body></html>"
    }

    // MARK: - Helpers

    /// Strips the common project root prefix from an absolute file path for display.
    private func relPath(_ path: String, root: String) -> String {
        guard !root.isEmpty, path.hasPrefix(root) else { return path }
        var rel = String(path.dropFirst(root.count))
        if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
        return rel.isEmpty ? path : rel
    }

    private func scoreGradientColor(_ score: Double, threshold: Double) -> String {
        guard score > 0     else { return "#34c759" }
        guard threshold > 0 else { return "#ff9500" }
        let ratio = min(score / threshold, 1.0)
        let r: Int, g: Int, b: Int
        if ratio < 0.5 {
            let t = ratio / 0.5
            r = Int((52  + t * (255 - 52 )).rounded())
            g = Int((199 + t * (204 - 199)).rounded())
            b = Int((89  + t * (0   - 89 )).rounded())
        } else {
            let t = (ratio - 0.5) / 0.5
            r = 255
            g = Int((204 + t * (59  - 204)).rounded())
            b = Int((0   + t * 48         ).rounded())
        }
        return String(format: "#%02x%02x%02x", r, g, b)
    }

    private func scoreBarColor(_ score: Double) -> String {
        if score == 0    { return "#34c759" }   // green  (✅ migrated)
        if score < 15    { return "#a3d977" }   // near-green (< 15)
        if score < 30    { return "#ff9500" }   // yellow (15–29)
        return "#ff3b30"                        // red    (≥ 30)
    }

    private func jsId(_ name: String) -> String {
        name.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? String($0) : "_"
        }.joined()
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
