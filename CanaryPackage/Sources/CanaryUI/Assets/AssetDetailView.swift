import SwiftUI
import CanaryEngine

public struct AssetDetailView: View {
    @Environment(Engine.self) private var engine
    let asset: MonitoredAsset
    var onBack: () -> Void
    @State private var showingDeleteConfirmation = false

    public init(asset: MonitoredAsset, onBack: @escaping () -> Void) {
        self.asset = asset
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Assets")
                    }
                    .font(Theme.captionFont)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, Theme.paddingLarge)
            .padding(.vertical, Theme.paddingMedium)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.paddingLarge) {
                    assetInfoSection
                    Divider()
                    actionButtons
                    Divider()
                    findingsSection
                }
                .padding(Theme.paddingLarge)
            }
        }
        .confirmationDialog(
            "Remove \(asset.label)?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Remove", role: .destructive) {
                try? engine.removeAsset(asset)
                onBack()
            }
        } message: {
            Text("This will remove \(asset.label) and all its findings. This cannot be undone.")
        }
    }

    private var currentAsset: MonitoredAsset {
        engine.assets.first(where: { $0.id == asset.id }) ?? asset
    }

    private var assetInfoSection: some View {
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(Theme.statusColor(for: currentAsset.status))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(currentAsset.label)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: Theme.paddingMedium) {
                    Text(currentAsset.kind.rawValue.capitalized)
                        .font(Theme.captionFont)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())

                    StatusBadge(status: currentAsset.status)

                    Text(currentAsset.status.rawValue.capitalized)
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }

                if let lastChecked = currentAsset.lastChecked {
                    Text("Last checked \(lastChecked, style: .relative) ago")
                        .font(Theme.captionFont)
                        .foregroundStyle(.tertiary)
                }

                Text("Added \(currentAsset.dateAdded, style: .date)")
                    .font(Theme.captionFont)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: Theme.paddingMedium) {
            Button {
                Task { await engine.scanSingleAsset(currentAsset) }
            } label: {
                Label("Scan Now", systemImage: "arrow.trianglehead.2.clockwise")
            }
            .disabled(engine.isScanning)

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var findingsSection: some View {
        let assetFindings = engine.recentFindings.filter { $0.assetID == asset.id }

        return VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            Text("Findings (\(assetFindings.count))")
                .font(.subheadline.bold())

            if assetFindings.isEmpty {
                Text("No findings for this asset.")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.paddingLarge)
            } else {
                ForEach(assetFindings) { finding in
                    TimelineRow(finding: finding)
                }
            }
        }
    }

    private var iconName: String {
        switch asset.kind {
        case .email: return "envelope.fill"
        case .password: return "key.fill"
        case .domain: return "globe"
        }
    }
}
