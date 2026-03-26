import SwiftUI
import CanaryEngine

public struct ScanHistoryView: View {
    @Environment(Engine.self) private var engine

    public init() {}

    public var body: some View {
        if engine.scanHistory.isEmpty {
            Text("No scan history yet")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: Theme.paddingSmall) {
                ForEach(engine.scanHistory.prefix(10)) { entry in
                    ScanHistoryRow(entry: entry)
                }
            }
        }
    }
}

struct ScanHistoryRow: View {
    let entry: ScanLogEntry

    var body: some View {
        HStack(spacing: Theme.paddingMedium) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.startedAt, style: .date)
                    .font(Theme.captionFont)

                HStack(spacing: Theme.paddingSmall) {
                    Text("\(entry.assetsScanned) assets")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text("\(entry.findingsCount) findings")
                        .font(.caption2)
                        .foregroundStyle(entry.findingsCount > 0 ? Theme.danger : .secondary)
                }
            }

            Spacer()

            if let duration = formattedDuration {
                Text(duration)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusIcon: String {
        switch entry.status {
        case "completed": return "checkmark.circle.fill"
        case "partial": return "exclamationmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        default: return "clock"
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case "completed": return Theme.safe
        case "partial": return Theme.warning
        case "failed": return Theme.danger
        default: return Theme.neutral
        }
    }

    private var formattedDuration: String? {
        guard let completed = entry.completedAt else { return nil }
        let seconds = Int(completed.timeIntervalSince(entry.startedAt))
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
}
