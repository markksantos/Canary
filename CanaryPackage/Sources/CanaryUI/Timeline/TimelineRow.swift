import SwiftUI
import CanaryEngine

public struct TimelineRow: View {
    let finding: Finding
    @State private var isExpanded = false

    public init(finding: Finding) {
        self.finding = finding
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack(spacing: Theme.paddingMedium) {
                Image(systemName: iconName)
                    .foregroundStyle(Theme.severityColor(for: finding.severity))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(finding.title)
                        .font(Theme.bodyFont)
                        .lineLimit(1)

                    Text(finding.source.rawValue.capitalized)
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(finding.date, style: .relative)
                    .font(Theme.captionFont)
                    .foregroundStyle(.tertiary)
            }

            if isExpanded {
                Text(finding.detail)
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
                    .padding(.top, 2)
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
    }

    private var iconName: String {
        switch finding.source {
        case .breach: return "exclamationmark.shield.fill"
        case .paste: return "doc.text.fill"
        case .passwordExposure: return "key.fill"
        case .dnsChange: return "network"
        }
    }
}
