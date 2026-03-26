import SwiftUI
import CanaryEngine

public struct BreachDetailCard: View {
    let finding: Finding
    let metadata: FindingMetadata

    public init(finding: Finding, metadata: FindingMetadata) {
        self.finding = finding
        self.metadata = metadata
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            // Domain and breach date
            HStack(spacing: Theme.paddingMedium) {
                if let domain = metadata.domain, !domain.isEmpty {
                    Text(domain)
                        .font(Theme.captionFont.bold())
                }

                if let date = metadata.breachDate {
                    Text(date)
                        .font(Theme.captionFont)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if let verified = metadata.isVerified, verified {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                        Text("Verified")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption2)
                }
            }

            // Affected count
            if let count = metadata.pwnCount, count > 0 {
                Text("\(count.formatted()) accounts affected")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }

            // Source provider
            if let provider = metadata.sourceProvider {
                Text("Source: \(provider == "hibp" ? "Have I Been Pwned" : "XposedOrNot")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Data class tags
            if let classes = metadata.dataClasses, !classes.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(classes, id: \.self) { dataClass in
                        Text(dataClass)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(tagColor(for: dataClass).opacity(0.15))
                            )
                            .foregroundStyle(tagColor(for: dataClass))
                    }
                }
            }

            // Change password link
            if let domain = metadata.domain, !domain.isEmpty,
               let url = URL(string: "https://\(domain)") {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Change Password", systemImage: "arrow.up.right.square")
                        .font(Theme.captionFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
        .padding(.leading, 24)
        .padding(.top, 2)
    }

    private func tagColor(for dataClass: String) -> Color {
        let lower = dataClass.lowercased()
        if lower.contains("password") { return Theme.danger }
        if lower.contains("email") { return .orange }
        if lower.contains("ip") || lower.contains("address") { return .purple }
        if lower.contains("phone") { return .indigo }
        return .secondary
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
