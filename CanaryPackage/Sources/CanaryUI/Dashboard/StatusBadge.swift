import SwiftUI
import CanaryEngine

public struct StatusBadge: View {
    let status: AssetStatus
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.8

    public init(status: AssetStatus) {
        self.status = status
    }

    public var body: some View {
        Circle()
            .fill(Theme.statusColor(for: status))
            .frame(width: 10, height: 10)
            .overlay {
                if status == .exposed {
                    Circle()
                        .stroke(Theme.statusColor(for: status), lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                                pulseScale = 2.0
                                pulseOpacity = 0
                            }
                        }
                }
            }
            .help(status.rawValue.capitalized)
    }
}
