import SwiftUI
import CanaryEngine
import ServiceManagement

public struct SettingsView: View {
    @Environment(Engine.self) private var engine

    @State private var selectedInterval: ScanScheduler.Interval = .twentyFourHours
    @State private var launchAtLogin = false

    public init() {}

    public var body: some View {
        Form {
            Section {
                APIKeySettingView()
            } header: {
                Label("API Key", systemImage: "key")
            }

            Section {
                NotificationSettingsView()
            } header: {
                Label("Notifications", systemImage: "bell")
            }

            Section {
                Picker("Interval", selection: $selectedInterval) {
                    ForEach(ScanScheduler.Interval.allCases, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .onChange(of: selectedInterval) { _, newValue in
                    engine.scheduler.updateInterval(newValue)
                    try? engine.database.saveSetting(key: "scanInterval", value: String(newValue.rawValue))
                }
            } header: {
                Label("Scan Frequency", systemImage: "clock.arrow.2.circlepath")
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
            } header: {
                Label("General", systemImage: "gear")
            }

            Section {
                ScanHistoryView()
            } header: {
                Label("Scan History", systemImage: "clock.arrow.circlepath")
            }

            Section {
                Button("Export PDF Report") {
                    Task { await exportPDF() }
                }
            } header: {
                Label("Import / Export", systemImage: "square.and.arrow.up")
            }

            Section {
                Button("Quit Canary", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if let saved = try? engine.database.loadSetting(key: "scanInterval"),
               let rawValue = Int(saved),
               let interval = ScanScheduler.Interval(rawValue: rawValue) {
                selectedInterval = interval
            }
        }
    }

    @MainActor
    private func exportPDF() async {
        let generator = PDFReportGenerator()
        do {
            let findings = engine.recentFindings
            let assets = engine.assets
            let data = try await generator.generateReport(assets: assets, findings: findings)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "Canary-Report-\(formattedDate).pdf"

            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url)
            }
        } catch {
            // Handle error
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
