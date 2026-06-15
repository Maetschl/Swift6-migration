import Swift6MigrationAnalyzerCore
import SwiftUI

struct AnalyzerDashboardView: View {
    @Bindable var model: AnalyzerAppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 290, ideal: 330)
        } detail: {
            DetailView(model: model)
        }
        .frame(minWidth: 1080, minHeight: 720)
        .alert(
            "Analyzer",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private struct SidebarView: View {
    @Bindable var model: AnalyzerAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            projectHeader

            Divider()

            controls

            Divider()

            HStack {
                Text("Modules")
                    .font(.headline)
                Spacer()
                Text("\(model.modules.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ModuleListView(model: model)
        }
        .padding(16)
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.projectName)
                .font(.title3.weight(.semibold))
                .lineLimit(2)

            if let selectedURL = model.selectedURL {
                Text(selectedURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Button {
                model.chooseProject()
            } label: {
                Label("Choose Project", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(value: $model.maxDepth, in: 1...12) {
                HStack {
                    Text("Max Depth")
                    Spacer()
                    Text("\(model.maxDepth)")
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Include Tests", isOn: $model.includeTests)

            Button {
                model.analyzeSelectedProject()
            } label: {
                Label(model.isAnalyzing ? "Analyzing" : "Analyze", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canAnalyze)

            if model.isAnalyzing {
                ProgressView()
                    .controlSize(.small)
            }

            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

private struct ModuleListView: View {
    @Bindable var model: AnalyzerAppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(model.modules, id: \.qualifiedName) { module in
                    ModuleRowView(
                        module: module,
                        isSelected: model.selectedModuleQualifiedName == module.qualifiedName
                    ) {
                        model.selectedModuleQualifiedName = module.qualifiedName
                    }
                }
            }
        }
        .overlay {
            if model.modules.isEmpty {
                ContentUnavailableView(
                    "No Analysis",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Choose a project and run analysis.")
                )
            }
        }
    }
}

private struct ModuleRowView: View {
    let module: ModuleResult
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                statusStrip

                VStack(alignment: .leading, spacing: 3) {
                    Text(module.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)

                    Text(module.aggregateStatus.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(scoreText(module.aggregateScore))
                        .font(.caption.weight(.semibold))
                    Text("\(module.aggregateFindings)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 7)
            .padding(.leading, CGFloat(module.depth * 14) + 6)
            .padding(.trailing, 8)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var statusStrip: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(statusColor(module.aggregateStatus))
            .frame(width: 4, height: 28)
    }
}

private struct DetailView: View {
    @Bindable var model: AnalyzerAppModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if model.modules.isEmpty {
                ContentUnavailableView(
                    "Ready",
                    systemImage: "swift",
                    description: Text("Select a Swift package, project folder, or Swift file.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SummaryGridView(summary: model.summary)

                        if let module = model.selectedModule {
                            SelectedModuleView(module: module, model: model)
                        }

                        FindingsView(model: model)
                    }
                    .padding(18)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.projectName)
                    .font(.title2.weight(.semibold))

                Text(runDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                ForEach(ExportFormat.allCases) { format in
                    Button {
                        model.export(format: format)
                    } label: {
                        Label(format.title, systemImage: exportIcon(format))
                    }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.down")
            }
            .disabled(model.modules.isEmpty)

            Button {
                model.analyzeSelectedProject()
            } label: {
                Label("Analyze", systemImage: "arrow.clockwise")
            }
            .disabled(!model.canAnalyze)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var runDetails: String {
        guard let lastRunDate = model.lastRunDate else {
            return model.statusMessage
        }
        let duration = model.lastRunDuration.map(AnalyzerAppModel.formatDuration) ?? "-"
        return "Last run \(lastRunDate.formatted(date: .abbreviated, time: .shortened)) · \(duration)"
    }
}

private struct SummaryGridView: View {
    let summary: AnalysisSummary

    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 190), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            SummaryTile(title: "Score", value: scoreText(summary.projectScore), systemImage: "gauge", tint: .orange)
            SummaryTile(title: "Modules", value: "\(summary.moduleCount)", systemImage: "square.stack.3d.up", tint: .blue)
            SummaryTile(title: "Migrated", value: "\(summary.migratedCount)", systemImage: "checkmark.circle", tint: .green)
            SummaryTile(title: "Findings", value: "\(summary.totalFindings)", systemImage: "list.bullet.rectangle", tint: .purple)
            SummaryTile(title: "Errors", value: "\(summary.totalErrors)", systemImage: "exclamationmark.octagon", tint: .red)
            SummaryTile(title: "Warnings", value: "\(summary.totalWarnings)", systemImage: "exclamationmark.triangle", tint: .yellow)
            SummaryTile(title: "Files", value: "\(summary.totalFiles)", systemImage: "doc.on.doc", tint: .teal)
            SummaryTile(title: "Lines", value: "\(summary.totalLines)", systemImage: "text.alignleft", tint: .indigo)
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 72)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SelectedModuleView: View {
    let module: ModuleResult
    @Bindable var model: AnalyzerAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(module.qualifiedName)
                        .font(.headline)
                    Text(model.displayPath(module.path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                StatusBadge(status: module.aggregateStatus)
            }

            HStack(spacing: 18) {
                MetricText(label: "Own Score", value: scoreText(module.score))
                MetricText(label: "Subtree", value: scoreText(module.aggregateScore))
                MetricText(label: "Files", value: "\(module.aggregateFileCount)")
                MetricText(label: "Lines", value: "\(module.aggregateLinesOfCode)")
                MetricText(label: "Findings", value: "\(module.aggregateFindings)")
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FindingsView: View {
    @Bindable var model: AnalyzerAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Findings")
                    .font(.headline)

                Picker("Severity", selection: $model.selectedSeverity) {
                    ForEach(SeverityFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 330)

                TextField("Search", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)

                Spacer()

                Text("\(model.filteredFindings.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                FindingHeaderRow()

                if model.filteredFindings.isEmpty {
                    Text("No findings match the current filters.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 110)
                } else {
                    ForEach(model.filteredFindings.prefix(500), id: \.stableID) { finding in
                        FindingRowView(finding: finding, model: model)
                    }

                    if model.filteredFindings.count > 500 {
                        Text("Showing first 500 findings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(10)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct FindingHeaderRow: View {
    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                Text("Severity").frame(width: 74, alignment: .leading)
                Text("Rule").frame(width: 190, alignment: .leading)
                Text("Location").frame(width: 260, alignment: .leading)
                Text("Message").gridCellColumns(2)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .separatorColor).opacity(0.22))
    }
}

private struct FindingRowView: View {
    let finding: Finding
    @Bindable var model: AnalyzerAppModel

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                SeverityBadge(severity: finding.severity)
                    .frame(width: 74, alignment: .leading)

                Text(finding.rule)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .frame(width: 190, alignment: .leading)

                Text("\(model.displayPath(finding.file)):\(finding.line)")
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 260, alignment: .leading)

                Text(finding.message)
                    .font(.caption)
                    .lineLimit(2)
                    .gridCellColumns(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct MetricText: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusBadge: View {
    let status: MigrationStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(statusColor(status))
            .background(statusColor(status).opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct SeverityBadge: View {
    let severity: Severity

    var body: some View {
        Text(severity.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(severityColor(severity))
            .background(severityColor(severity).opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

private extension Finding {
    var stableID: String {
        "\(file):\(line):\(column):\(rule):\(message)"
    }
}

private func scoreText(_ score: Double) -> String {
    String(format: "%.2f", score)
}

private func statusColor(_ status: MigrationStatus) -> Color {
    if status.isPendingMigration {
        return .orange
    }
    if status.hasWarnings {
        return .yellow
    }
    return .green
}

private func severityColor(_ severity: Severity) -> Color {
    switch severity {
    case .error: return .red
    case .warning: return .orange
    case .info: return .blue
    }
}

private func exportIcon(_ format: ExportFormat) -> String {
    switch format {
    case .markdown: return "doc.plaintext"
    case .json: return "curlybraces"
    case .html: return "safari"
    }
}
