import Foundation

public struct XONBreach: Sendable {
    public let breachName: String
    public let domain: String
    public let exposedDate: String
    public let exposedData: [String]
    public let exposedRecords: Int
}

struct XONResponse: Decodable {
    let breaches: [String]?
    let exposedBreaches: XONExposedBreaches?

    enum CodingKeys: String, CodingKey {
        case breaches
        case exposedBreaches = "ExposedBreaches"
    }
}

struct XONExposedBreaches: Decodable {
    let breachesDetails: [XONBreachDetail]?

    enum CodingKeys: String, CodingKey {
        case breachesDetails = "breaches_details"
    }
}

struct XONBreachDetail: Decodable {
    let breach: String?
    let domain: String?
    let exposedDate: String?
    let exposedData: String?
    let exposedRecords: Int?

    enum CodingKeys: String, CodingKey {
        case breach
        case domain
        case exposedDate = "xposed_date"
        case exposedData = "xposed_data"
        case exposedRecords = "xposed_records"
    }

    func toXONBreach() -> XONBreach {
        XONBreach(
            breachName: breach ?? "Unknown",
            domain: domain ?? "",
            exposedDate: exposedDate ?? "",
            exposedData: (exposedData ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            exposedRecords: exposedRecords ?? 0
        )
    }
}
