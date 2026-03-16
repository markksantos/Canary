import SwiftUI
import CanaryEngine

public struct DashboardView: View {
    @Environment(Engine.self) private var engine

    @State private var showingAddEmail = false
    @State private var showingAddPassword = false
    @State private var showingAddDomain = false
    @State private var showingSettings = false
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabPicker
            Divider()

            switch selectedTab {
            case 0:
                assetList
            case 1:
                TimelineView()
            case 2:
                SettingsView()
            default:
                assetList
            }
        }
        .frame(width: Theme.popoverWidth, height: Theme.popoverHeight)
        .sheet(isPresented: $showingAddEmail) { AddEmailView() }
        .sheet(isPresented: $showingAddPassword) { AddPasswordView() }
        .sheet(isPresented: $showingAddDomain) { AddDomainView() }
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

            Button(action: { Task { await engine.runFullScan() } }) {
                Image(systemName: "arrow.trianglehead.2.clockwise")
            }
            .disabled(engine.isScanning || !engine.apiKeyConfigured)
            .help(engine.apiKeyConfigured ? "Check Now" : "Set API key first")

            Menu {
                Button("Add Email...") { showingAddEmail = true }
                Button("Add Password...") { showingAddPassword = true }
                Button("Add Domain...") { showingAddDomain = true }
            } label: {
                Image(systemName: "plus")
            }
        }
        .padding(Theme.paddingLarge)
    }

    @ViewBuilder
    private var statusText: some View {
        switch engine.scanState {
        case .idle:
            Text(engine.assets.isEmpty ? "No assets monitored" : "\(engine.assets.count) assets monitored")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        case .scanning(let progress):
            Text("Scanning... \(Int(progress * 100))%")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        case .completed(let date):
            Text("Last scan: \(date, style: .relative) ago")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.danger)
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                AssetListView()
            }
        }
    }
}
