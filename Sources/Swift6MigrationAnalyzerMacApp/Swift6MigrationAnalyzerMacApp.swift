import SwiftUI

@main
struct Swift6MigrationAnalyzerMacApp: App {
    @State private var model = AnalyzerAppModel()

    var body: some Scene {
        WindowGroup {
            AnalyzerDashboardView(model: model)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Project...") {
                    model.chooseProject()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Run Analysis") {
                    model.analyzeSelectedProject()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!model.canAnalyze)
            }

            CommandMenu("Reports") {
                ForEach(ExportFormat.allCases) { format in
                    Button("Export \(format.title)...") {
                        model.export(format: format)
                    }
                    .disabled(model.modules.isEmpty)
                }
            }
        }
    }
}
