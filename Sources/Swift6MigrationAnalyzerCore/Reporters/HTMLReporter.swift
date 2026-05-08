import Foundation

public struct HTMLReporter: Reporter {
    public init() {}

    // MARK: - Module-aware dashboard

    public func generate(modules: [ModuleResult], projectName: String) -> String {
        let allFindings  = modules.flatMap { $0.findings }
        let projectScore = modules.reduce(0.0) { $0 + $1.score }
        let projectStatus: MigrationStatus = projectScore == 0 ? .migrated : .pendingMigration
        let totalErrors   = allFindings.filter { $0.severity == .error }.count
        let totalWarnings = allFindings.filter { $0.severity == .warning }.count
        let totalFiles    = modules.reduce(0) { $0 + $1.fileCount }
        let totalLines    = modules.reduce(0) { $0 + $1.totalLinesOfCode }

        // Indicators totals
        let totalActors    = modules.reduce(0) { $0 + $1.migrationIndicators.actorDeclarationCount }
        let totalMainActor = modules.reduce(0) { $0 + $1.migrationIndicators.mainActorAnnotationCount }
        let totalAsync     = modules.reduce(0) { $0 + $1.migrationIndicators.asyncFunctionCount }
        let totalSendable  = modules.reduce(0) { $0 + $1.migrationIndicators.sendableConformanceCount }

        let moduleRows = modules.map { module -> String in
            let scoreColor = module.status == .migrated ? "#34c759" : "#ff9500"
            let ind = module.migrationIndicators
            return """
            <tr onclick="showModule('\(jsId(module.qualifiedName))')" style="cursor:pointer">
              <td style="padding-left:\(8 + module.depth * 16)px">\(module.depth > 0 ? "<span style='color:#aaa;margin-right:4px'>" + String(repeating: "›", count: module.depth) + "</span>" : "")<strong>\(escapeHTML(module.qualifiedName))</strong></td>
              <td><span class="status-badge \(module.status.htmlClass)">\(module.status.icon) \(escapeHTML(module.status.rawValue))</span></td>
              <td><span class="score-pill" style="background:\(scoreColor)20;color:\(scoreColor)">\(String(format: "%.2f", module.score))</span></td>
              <td>\(module.fileCount)</td>
              <td>\(module.findings.count)</td>
              <td class="indicator">\(ind.actorDeclarationCount)</td>
              <td class="indicator">\(ind.mainActorAnnotationCount)</td>
              <td class="indicator">\(ind.asyncFunctionCount)</td>
            </tr>
            """
        }.joined()

        let moduleDetailSections = modules.map { module -> String in
            let ind = module.migrationIndicators
            let indicatorBar = """
            <div class="indicator-bar">
              <span class="ind-chip actor">\(ind.actorDeclarationCount) actors</span>
              <span class="ind-chip mainactor">\(ind.mainActorAnnotationCount) @MainActor</span>
              <span class="ind-chip async">\(ind.asyncFunctionCount) async</span>
              <span class="ind-chip sendable">\(ind.sendableConformanceCount) Sendable</span>
            </div>
            """

            if module.findings.isEmpty {
                return """
                <div id="module-\(jsId(module.qualifiedName))" class="module-detail" style="display:none">
                  <div class="module-header">
                    <h2>\(module.status.icon) \(escapeHTML(module.qualifiedName))</h2>
                    <span class="status-badge migrated">\(module.status.icon) \(escapeHTML(module.status.rawValue))</span>
                  </div>
                  \(indicatorBar)
                  <p class="empty-state">✅ No migration issues found in this module.</p>
                </div>
                """
            }

            let byRule = Dictionary(grouping: module.findings, by: \.rule)
            let ruleCards = byRule.keys.sorted().map { ruleName -> String in
                let ruleFindings = byRule[ruleName] ?? []
                let weight = FindingComplexity.weight(for: ruleName)
                let items = ruleFindings.map { f -> String in
                    "<li><span class=\"badge \(f.severity.htmlClass)\">\(f.severity.rawValue)</span> <code>\(escapeHTML(f.location))</code> — \(escapeHTML(f.message))</li>"
                }.joined(separator: "\n")
                return """
                <div class="rule-card">
                  <div class="rule-header">
                    <span class="rule-name">\(escapeHTML(ruleName))</span>
                    <span class="weight-pill">weight \(weight)</span>
                    <span class="count">\(ruleFindings.count)</span>
                  </div>
                  <ul>\(items)</ul>
                </div>
                """
            }.joined()

            return """
            <div id="module-\(jsId(module.qualifiedName))" class="module-detail" style="display:none">
              <div class="module-header">
                <h2>\(module.status.icon) \(escapeHTML(module.qualifiedName))</h2>
                <span class="status-badge \(module.status.htmlClass)">\(escapeHTML(module.status.rawValue))</span>
                <span class="score-pill-lg">Score \(String(format: "%.2f", module.score))</span>
                <span class="meta">\(module.fileCount) files · \(module.totalLinesOfCode) lines</span>
              </div>
              \(indicatorBar)
              \(ruleCards)
            </div>
            """
        }.joined()

        // All findings table
        let allRows = allFindings.map { f -> String in
            let fileName = f.file.components(separatedBy: "/").last ?? f.file
            return """
            <tr class="\(f.severity.htmlClass)">
              <td>\(escapeHTML(fileName)):\(f.line)</td>
              <td><span class="badge \(f.severity.htmlClass)">\(f.severity.rawValue.uppercased())</span></td>
              <td>\(escapeHTML(f.rule))</td>
              <td>\(String(format: "%.1f", FindingComplexity.weight(for: f.rule)))</td>
              <td>\(escapeHTML(f.message))</td>
            </tr>
            """
        }.joined()

        // Complexity table
        let weightRows = FindingComplexity.weightTable.map { entry -> String in
            "<tr><td><code>\(escapeHTML(entry.rule))</code></td><td><strong>\(entry.weight)</strong></td><td>\(escapeHTML(entry.rationale))</td></tr>"
        }.joined()

        let statusColor = projectStatus == .migrated ? "#34c759" : "#ff9500"

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Swift 6 Migration — \(escapeHTML(projectName))</title>
        <style>
          *{box-sizing:border-box;margin:0;padding:0}
          body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f5f5f7;color:#1d1d1f}
          header{background:#1d1d1f;color:#fff;padding:2rem 2.5rem}
          header h1{font-size:1.8rem}
          header .subtitle{opacity:.65;margin-top:.4rem;font-size:.95rem}
          .project-status{display:inline-flex;align-items:center;gap:.5rem;margin-top:.75rem;padding:.4rem .9rem;border-radius:999px;font-weight:700;font-size:.9rem;background:\(statusColor)22;color:\(statusColor)}
          .summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:1rem;padding:1.5rem 2.5rem}
          .stat{background:#fff;border-radius:14px;padding:1rem 1.25rem;box-shadow:0 1px 4px rgba(0,0,0,.08)}
          .stat .num{font-size:1.8rem;font-weight:700}
          .stat .lbl{color:#6e6e73;font-size:.78rem;margin-top:.2rem}
          .stat.score .num{color:#ff9500}
          .stat.errors .num{color:#ff3b30}
          .stat.warnings .num{color:#ff9500}
          .stat.positive .num{color:#34c759}
          .indicators-strip{display:flex;gap:.75rem;padding:0 2.5rem 1.25rem;flex-wrap:wrap}
          .ind-stat{background:#f0fdf4;border:1px solid #bbf7d0;border-radius:10px;padding:.5rem .9rem;font-size:.85rem}
          .ind-stat strong{color:#16a34a;font-size:1.1rem;margin-right:.3rem}
          nav{display:flex;gap:.5rem;padding:0 2.5rem 1rem;flex-wrap:wrap}
          nav button{background:#fff;border:1.5px solid #d1d1d6;border-radius:8px;padding:.45rem .9rem;font-size:.85rem;cursor:pointer;transition:all .15s}
          nav button.active,nav button:hover{background:#1d1d1f;color:#fff;border-color:#1d1d1f}
          .panel{display:none;padding:0 2.5rem 2.5rem}
          .panel.active{display:block}
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
          .status-badge{display:inline-block;border-radius:999px;padding:.2rem .7rem;font-size:.8rem;font-weight:600}
          .status-badge.migrated{background:#34c75922;color:#34c759}
          .status-badge.pending{background:#ff950022;color:#ff9500}
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
        </style>
        </head>
        <body>
        <header>
          <h1>🔍 Swift 6 Migration Report</h1>
          <div class="subtitle">\(escapeHTML(projectName)) · Generated \(Date().formatted())</div>
          <div class="project-status">\(projectStatus.icon) \(projectStatus.rawValue)</div>
        </header>

        <div class="summary-grid">
          <div class="stat score"><div class="num">\(String(format: "%.2f", projectScore))</div><div class="lbl">Migration Score</div></div>
          <div class="stat"><div class="num">\(modules.count)</div><div class="lbl">Modules</div></div>
          <div class="stat errors"><div class="num">\(totalErrors)</div><div class="lbl">Errors</div></div>
          <div class="stat warnings"><div class="num">\(totalWarnings)</div><div class="lbl">Warnings</div></div>
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
          <button onclick="showPanel('all-findings')">All Findings</button>
          <button onclick="showPanel('complexity')">Complexity Table</button>
        </nav>

        <!-- Modules panel -->
        <div id="panel-modules" class="panel active">
          <h2 class="section-title">Module Overview</h2>
          <table id="modules-table">
            <thead>
              <tr>
                <th onclick="sortTable('modules-table',0)">Module ↕</th>
                <th onclick="sortTable('modules-table',1)">Status ↕</th>
                <th onclick="sortTable('modules-table',2)">Score ↕</th>
                <th onclick="sortTable('modules-table',3)">Files ↕</th>
                <th onclick="sortTable('modules-table',4)">Findings ↕</th>
                <th onclick="sortTable('modules-table',5)" title="actor declarations">Actors ↕</th>
                <th onclick="sortTable('modules-table',6)" title="@MainActor">@Main ↕</th>
                <th onclick="sortTable('modules-table',7)" title="async functions">async ↕</th>
              </tr>
            </thead>
            <tbody>\(moduleRows)</tbody>
          </table>

          <div id="module-details" style="margin-top:1.5rem;display:none">
            <button class="back-btn" onclick="hideModuleDetails()">← Back to module list</button>
            \(moduleDetailSections)
          </div>
        </div>

        <!-- All findings panel -->
        <div id="panel-all-findings" class="panel">
          <h2 class="section-title">All Findings (\(allFindings.count))</h2>
          <table id="findings-table">
            <thead>
              <tr>
                <th onclick="sortTable('findings-table',0)">Location ↕</th>
                <th onclick="sortTable('findings-table',1)">Severity ↕</th>
                <th onclick="sortTable('findings-table',2)">Rule ↕</th>
                <th onclick="sortTable('findings-table',3)">Weight ↕</th>
                <th>Message</th>
              </tr>
            </thead>
            <tbody>\(allRows)</tbody>
          </table>
        </div>

        <!-- Complexity table panel -->
        <div id="panel-complexity" class="panel">
          <h2 class="section-title">Finding Complexity Weight Table</h2>
          <p style="color:#6e6e73;font-size:.9rem;margin-bottom:1rem">Score formula: <strong>SUM(finding × complexity weight)</strong>. Higher score = more migration effort required.</p>
          <table>
            <thead><tr><th>Rule</th><th>Weight</th><th>Rationale</th></tr></thead>
            <tbody>\(weightRows)</tbody>
          </table>
        </div>

        <script>
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
            detail.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        }
        function hideModuleDetails() {
          document.getElementById('module-details').style.display = 'none';
          document.getElementById('modules-table').style.display = 'table';
          document.querySelectorAll('.module-detail').forEach(d => d.style.display = 'none');
        }
        function sortTable(tableId, col) {
          const table = document.getElementById(tableId);
          const tbody = table.tBodies[0];
          const rows = Array.from(tbody.rows);
          const asc = table.dataset.sortCol == col && table.dataset.sortDir === 'asc';
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
                ruleCards += "<li><span>\(f.severity.rawValue)</span> <code>\(escapeHTML(f.location))</code> — \(escapeHTML(f.message))</li>"
            }
            ruleCards += "</ul></div>"
        }
        return "<html><body><h1>Swift 6 Report</h1><p>Errors: \(totalErrors) · Warnings: \(totalWarnings)</p>\(ruleCards)</body></html>"
    }

    // MARK: - Helpers

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
