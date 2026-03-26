import SwiftUI
import CanaryEngine

public struct TimelineRow: View {
    let finding: Finding
    @State private var isExpanded = false
    @State private var isHovered = false

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

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(Theme.springAnimation, value: isExpanded)
            }

            if isExpanded {
                Group {
                    if finding.source == .breach, let meta = finding.metadata {
                        BreachDetailCard(finding: finding, metadata: meta)
                    } else {
                        Text(finding.displayDetail)
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 24)
                            .padding(.top, 2)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.paddingMedium)
        .background {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Theme.springAnimation) {
                isExpanded.toggle()
            }
        }
        .onHover { isHovered = $0 }
        .animation(Theme.standardAnimation, value: isHovered)
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
