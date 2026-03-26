import SwiftUI
import CanaryEngine

public struct AssetListView: View {
    @Environment(Engine.self) private var engine
    @State private var assetToDelete: MonitoredAsset?
    @State private var showingDeleteConfirmation = false

    var onSelectAsset: ((MonitoredAsset) -> Void)?

    public init(onSelectAsset: ((MonitoredAsset) -> Void)? = nil) {
        self.onSelectAsset = onSelectAsset
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.paddingSmall) {
                ForEach(engine.assets) { asset in
                    AssetSummaryCard(asset: asset)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectAsset?(asset) }
                        .contextMenu {
                            Button("Remove", role: .destructive) {
                                assetToDelete = asset
                                showingDeleteConfirmation = true
                            }
                        }
                }
            }
            .padding(Theme.paddingMedium)
            .animation(Theme.standardAnimation, value: engine.assets.map(\.id))
        }
        .confirmationDialog(
            "Remove \(assetToDelete?.label ?? "asset")?",
            isPresented: $showingDeleteConfirmation,
            presenting: assetToDelete
        ) { asset in
            Button("Remove", role: .destructive) {
                try? engine.removeAsset(asset)
            }
        } message: { asset in
            Text("This will remove \(asset.label) and all its findings. This cannot be undone.")
        }
    }
}
