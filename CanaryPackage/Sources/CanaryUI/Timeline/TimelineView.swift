import SwiftUI
import CanaryEngine

public struct TimelineView: View {
    @Environment(Engine.self) private var engine

    public init() {}

    public var body: some View {
        Group {
            if engine.recentFindings.isEmpty {
                VStack(spacing: Theme.paddingMedium) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No findings yet")
                        .foregroundStyle(.secondary)
                    Text("Run a scan to check your assets against known breaches.")
                        .font(Theme.captionFont)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.paddingSmall) {
                        ForEach(groupedFindings, id: \.key) { date, findings in
                            Section {
                                ForEach(findings) { finding in
                                    TimelineRow(finding: finding)
                                }
                            } header: {
                                Text(date, style: .date)
                                    .font(Theme.captionFont.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, Theme.paddingSmall)
                            }
                        }
                    }
                    .padding(Theme.paddingMedium)
                }
            }
        }
    }

    private var groupedFindings: [(key: Date, value: [Finding])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: engine.recentFindings) { finding in
            calendar.startOfDay(for: finding.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}
