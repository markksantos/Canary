import Foundation

public struct BreachModel: Codable, Identifiable, Equatable, Sendable {
    public let name: String
    public let title: String
    public let domain: String
    public let breachDate: String
    public let addedDate: String
    public let modifiedDate: String
    public let pwnCount: Int
    public let description: String
    public let logoPath: String
    public let dataClasses: [String]
    public let isVerified: Bool
    public let isFabricated: Bool
    public let isSensitive: Bool
    public let isRetired: Bool
    public let isSpamList: Bool
    public let isMalware: Bool
    public let isSubscriptionFree: Bool

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case title = "Title"
        case domain = "Domain"
        case breachDate = "BreachDate"
        case addedDate = "AddedDate"
        case modifiedDate = "ModifiedDate"
        case pwnCount = "PwnCount"
        case description = "Description"
        case logoPath = "LogoPath"
        case dataClasses = "DataClasses"
        case isVerified = "IsVerified"
        case isFabricated = "IsFabricated"
        case isSensitive = "IsSensitive"
        case isRetired = "IsRetired"
        case isSpamList = "IsSpamList"
        case isMalware = "IsMalware"
        case isSubscriptionFree = "IsSubscriptionFree"
    }
}

public struct PasteModel: Codable, Identifiable, Equatable, Sendable {
    public let source: String
    public let id: String
    public let title: String?
    public let date: String?
    public let emailCount: Int

    enum CodingKeys: String, CodingKey {
        case source = "Source"
        case id = "Id"
        case title = "Title"
        case date = "Date"
        case emailCount = "EmailCount"
    }
}
