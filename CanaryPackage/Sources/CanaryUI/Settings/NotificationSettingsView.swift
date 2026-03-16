import SwiftUI
import CanaryEngine

public struct NotificationSettingsView: View {
    @Environment(Engine.self) private var engine

    @State private var breachEnabled = true
    @State private var pasteEnabled = true
    @State private var dnsEnabled = true

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            Text("Notifications")
                .font(Theme.bodyFont.bold())

            Toggle("Breach alerts", isOn: $breachEnabled)
                .onChange(of: breachEnabled) { _, val in
                    engine.notificationManager.breachNotificationsEnabled = val
                }
            Toggle("Paste alerts", isOn: $pasteEnabled)
                .onChange(of: pasteEnabled) { _, val in
                    engine.notificationManager.pasteNotificationsEnabled = val
                }
            Toggle("DNS change alerts", isOn: $dnsEnabled)
                .onChange(of: dnsEnabled) { _, val in
                    engine.notificationManager.dnsNotificationsEnabled = val
                }
        }
        .onAppear {
            breachEnabled = engine.notificationManager.breachNotificationsEnabled
            pasteEnabled = engine.notificationManager.pasteNotificationsEnabled
            dnsEnabled = engine.notificationManager.dnsNotificationsEnabled
        }
    }
}
