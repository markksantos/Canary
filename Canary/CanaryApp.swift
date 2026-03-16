import SwiftUI
import CanaryEngine
import CanaryUI

@main
struct CanaryApp: App {
    @State private var engine = Engine()

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environment(engine)
                .task { await engine.start() }
        } label: {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        Theme.menuBarIconName(
            hasExposure: engine.overallStatus == .exposed,
            isScanning: engine.isScanning
        )
    }
}
