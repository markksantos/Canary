import SwiftUI
import CanaryEngine

public struct AssetListView: View {
    @Environment(Engine.self) private var engine

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.paddingSmall) {
                ForEach(engine.assets) { asset in
                    AssetSummaryCard(asset: asset)
                        .contextMenu {
                            Button("Remove") {
                                try? engine.removeAsset(asset)
                            }
                        }
                }
            }
            .padding(Theme.paddingMedium)
        }
    }
}
