import SwiftUI
import CanaryEngine

public enum Theme {
    // MARK: - Colors
    public static let safe = Color.green
    public static let warning = Color.yellow
    public static let danger = Color.red
    public static let neutral = Color.secondary
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let cardBackground = Color(nsColor: .controlBackgroundColor)

    // MARK: - Spacing
    public static let paddingSmall: CGFloat = 4
    public static let paddingMedium: CGFloat = 8
    public static let paddingLarge: CGFloat = 16
    public static let paddingXL: CGFloat = 24

    // MARK: - Sizes
    public static let popoverWidth: CGFloat = 360
    public static let popoverHeight: CGFloat = 480
    public static let cardCornerRadius: CGFloat = 8
    public static let modalWidth: CGFloat = 320
    public static let iconSize: CGFloat = 20

    // MARK: - Materials & Animations
    public static let popoverMaterial: Material = .ultraThinMaterial
    public static let standardAnimation: Animation = .easeInOut(duration: 0.2)
    public static let springAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.8)

    // MARK: - Fonts
    public static let titleFont = Font.headline
    public static let bodyFont = Font.body
    public static let captionFont = Font.caption
    public static let monoFont = Font.system(.body, design: .monospaced)

    // MARK: - Helpers
    public static func statusColor(for status: CanaryEngine.AssetStatus) -> Color {
        switch status {
        case .safe: return safe
        case .exposed: return danger
        case .unknown: return neutral
        }
    }

    public static func severityColor(for severity: CanaryEngine.Severity) -> Color {
        switch severity {
        case .low: return .blue
        case .medium: return warning
        case .high: return .orange
        case .critical: return danger
        }
    }

    public static func menuBarIconName(hasExposure: Bool, isScanning: Bool) -> String {
        if isScanning { return "arrow.trianglehead.2.clockwise" }
        return hasExposure ? "bird.fill" : "bird"
    }
}
