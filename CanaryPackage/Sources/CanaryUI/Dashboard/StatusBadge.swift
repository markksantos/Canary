import SwiftUI
import CanaryEngine

public struct StatusBadge: View {
    let status: AssetStatus

    public init(status: AssetStatus) {
        self.status = status
    }

    public var body: some View {
        Circle()
            .fill(Theme.statusColor(for: status))
            .frame(width: 10, height: 10)
    }
}
