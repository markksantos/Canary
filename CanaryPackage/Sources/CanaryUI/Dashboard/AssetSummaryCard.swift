import SwiftUI
import CanaryEngine

public struct AssetSummaryCard: View {
    let asset: MonitoredAsset

    @State private var isHovered = false

    public init(asset: MonitoredAsset) {
        self.asset = asset
    }

    public var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: iconName)
                .foregroundStyle(Theme.statusColor(for: asset.status))
                .frame(width: Theme.iconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.label)
                    .font(Theme.bodyFont)
                    .lineLimit(1)

                HStack(spacing: Theme.paddingSmall) {
                    Text(asset.kind.rawValue.capitalized)
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)

                    if let lastChecked = asset.lastChecked {
                        Text("Checked \(lastChecked, style: .relative) ago")
                            .font(Theme.captionFont)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if asset.findingCount > 0 {
                Text("\(asset.findingCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.danger, in: Capsule())
            }

            StatusBadge(status: asset.status)
        }
        .padding(Theme.paddingMedium)
        .background {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        }
        .onHover { isHovered = $0 }
        .animation(Theme.standardAnimation, value: isHovered)
    }

    private var iconName: String {
        switch asset.kind {
        case .email: return "envelope.fill"
        case .password: return "key.fill"
        case .domain: return "globe"
        }
    }
}
