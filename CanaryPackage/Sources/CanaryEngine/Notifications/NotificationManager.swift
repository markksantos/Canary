import Foundation
import UserNotifications

public final class NotificationManager {
    public static let breachCategory = "BREACH_FOUND"
    public static let pasteCategory = "PASTE_FOUND"
    public static let dnsCategory = "DNS_CHANGE"

    private let center = UNUserNotificationCenter.current()

    public var breachNotificationsEnabled = true
    public var pasteNotificationsEnabled = true
    public var dnsNotificationsEnabled = true

    public init() {}

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func registerCategories() {
        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(identifier: Self.breachCategory, actions: [], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.pasteCategory, actions: [], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.dnsCategory, actions: [], intentIdentifiers: []),
        ]
        center.setNotificationCategories(categories)
    }

    public func sendBreachNotification(assetLabel: String, breachName: String) async {
        guard breachNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Breach Detected"
        content.body = "\(assetLabel) was found in the \(breachName) breach"
        content.sound = .default
        content.categoryIdentifier = Self.breachCategory

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    public func sendPasteNotification(assetLabel: String, source: String) async {
        guard pasteNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Paste Detected"
        content.body = "\(assetLabel) was found in a paste on \(source)"
        content.sound = .default
        content.categoryIdentifier = Self.pasteCategory

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    public func sendDNSChangeNotification(domain: String, recordType: String) async {
        guard dnsNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "DNS Change Detected"
        content.body = "\(recordType) records changed for \(domain)"
        content.sound = .default
        content.categoryIdentifier = Self.dnsCategory

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
