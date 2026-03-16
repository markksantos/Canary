import SwiftUI
import CanaryEngine
import ServiceManagement

public struct SettingsView: View {
    @Environment(Engine.self) private var engine

    @State private var selectedInterval: ScanScheduler.Interval = .twentyFourHours
    @State private var launchAtLogin = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingLarge) {
                APIKeySettingView()

                Divider()

                NotificationSettingsView()

                Divider()

                scanFrequencySection

                Divider()

                launchAtLoginSection

                Divider()

                exportSection
            }
            .padding(Theme.paddingLarge)
        }
    }

    private var scanFrequencySection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            Text("Scan Frequency")
                .font(Theme.bodyFont.bold())

            Picker("Interval", selection: $selectedInterval) {
                ForEach(ScanScheduler.Interval.allCases, id: \.self) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .onChange(of: selectedInterval) { _, newValue in
                engine.scheduler.updateInterval(newValue)
            }
        }
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            Text("General")
                .font(Theme.bodyFont.bold())

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            Text("Export")
                .font(Theme.bodyFont.bold())

            Button("Export PDF Report") {
                Task { await exportPDF() }
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
