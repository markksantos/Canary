import SwiftUI
import CanaryEngine

public struct DashboardView: View {
    @Environment(Engine.self) private var engine

    @State private var showingAddEmail = false
    @State private var showingAddPassword = false
    @State private var showingAddDomain = false
    @State private var showingCSVImport = false
    @State private var showingSettings = false
    @State private var showingQuitConfirmation = false
    @State private var selectedTab = 0
    @State private var selectedAsset: MonitoredAsset?

    public init() {}

    public var body: some View {
        mainContent
            .background(.ultraThinMaterial)
            .frame(width: Theme.popoverWidth, height: Theme.popoverHeight)
            .sheet(isPresented: $showingAddEmail) { AddEmailView() }
            .sheet(isPresented: $showingAddPassword) { AddPasswordView() }
            .sheet(isPresented: $showingAddDomain) { AddDomainView() }
            .sheet(isPresented: $showingCSVImport) { CSVImportView() }
            .confirmationDialog("Quit Canary?", isPresented: $showingQuitConfirmation) {
                Button("Quit", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            } message: {
                Text("Canary will stop monitoring for breaches until you reopen it.")
            }
            .onAppear { engine.markFindingsViewed() }
            .background {
                KeyboardShortcutHandler(
                    engine: engine,
                    showingAddEmail: $showingAddEmail,
                    showingAddDomain: $showingAddDomain,
                    selectedTab: $selectedTab,
                    selectedAsset: $selectedAsset
                )
            }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let asset = selectedAsset {
                AssetDetailView(asset: asset, onBack: { selectedAsset = nil })
            } else {
                header
                Divider()
                tabPicker
                Divider()
                tabContent
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: assetList
        case 1: TimelineView()
        case 2: SettingsView()
        default: assetList
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Canary")
                    .font(.headline)
                statusText
            }

            Spacer()

            if engine.isScanning {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
            }

            scanButton
            headerMenu
        }
        .padding(Theme.paddingLarge)
    }

    private var scanButton: some View {
        Button(action: { Task { await engine.runFullScan() } }) {
            Image(systemName: "arrow.trianglehead.2.clockwise")
        }
        .disabled(engine.isScanning || !engine.apiKeyConfigured)
        .help(engine.apiKeyConfigured ? "Check Now (⌘R)" : "Set API key first")
    }

    private var headerMenu: some View {
        Menu {
            Button("Add Email... ⌘E") { showingAddEmail = true }
            Button("Add Password...") { showingAddPassword = true }
            Button("Add Domain... ⌘D") { showingAddDomain = true }
            Divider()
            Button("Import CSV...") { showingCSVImport = true }
            Divider()
            Button("Settings...") { selectedTab = 2 }
            Divider()
            Button("Quit Canary") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch engine.scanState {
        case .idle:
            idleStatusText
        case .scanning(let progress):
            Text("Scanning... \(Int(progress * 100))%")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        case .completed(let date):
            completedStatusText(date: date)
        case .failed(let message):
            Text(message)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.danger)
        }
    }

    private var idleStatusText: some View {
        Text(engine.assets.isEmpty ? "No assets monitored" : "\(engine.assets.count) assets monitored")
            .font(Theme.captionFont)
            .foregroundStyle(.secondary)
    }

    private func completedStatusText(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Last scan: \(date, style: .relative) ago")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
            if engine.weeklyNewFindings > 0 {
                Text("\(engine.weeklyNewFindings) new this week")
                    .font(.caption2)
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text("Assets").tag(0)
            Text("Timeline").tag(1)
            Text("Settings").tag(2)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.paddingLarge)
        .padding(.vertical, Theme.paddingSmall)
    }

    private var assetList: some View {
        Group {
            if engine.assets.isEmpty {
                emptyAssetList
            } else {
                AssetListView(onSelectAsset: { asset in
                    withAnimation(Theme.standardAnimation) {
                        selectedAsset = asset
                    }
                })
            }
        }
    }

    private var emptyAssetList: some View {
        VStack(spacing: Theme.paddingMedium) {
            Image(systemName: "shield.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No assets monitored")
                .foregroundStyle(.secondary)
            Text("Add an email, password, or domain to start monitoring.")
                .font(Theme.captionFont)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Add Your First Asset") {
                showingAddEmail = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct KeyboardShortcutHandler: NSViewRepresentable {
    let engine: Engine
    @Binding var showingAddEmail: Bool
    @Binding var showingAddDomain: Bool
    @Binding var selectedTab: Int
    @Binding var selectedAsset: MonitoredAsset?

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onKeyDown = { [self] event in
            guard event.modifierFlags.contains(.command) else { return false }
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }

            switch chars {
            case "r":
                guard engine.apiKeyConfigured, !engine.isScanning else { return false }
                Task { await engine.runFullScan() }
                return true
            case "e":
                showingAddEmail = true
                return true
            case "d":
                showingAddDomain = true
                return true
            case "1":
                selectedTab = 0; selectedAsset = nil; return true
            case "2":
                selectedTab = 1; selectedAsset = nil; return true
            case "3":
                selectedTab = 2; selectedAsset = nil; return true
            default:
                return false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }
}
