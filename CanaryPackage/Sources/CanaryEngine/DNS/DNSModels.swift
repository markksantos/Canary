import Foundation

public enum DNSRecordType: String, Codable, CaseIterable, Sendable {
    case a = "A"
    case mx = "MX"
    case ns = "NS"
    case txt = "TXT"
}

public struct DNSRecord: Codable, Equatable, Sendable {
    public let type: DNSRecordType
    public let value: String

    public init(type: DNSRecordType, value: String) {
        self.type = type
        self.value = value
    }
}

public struct DNSBaseline: Identifiable, Codable, Sendable {
    public let id: UUID
    public let assetID: UUID
    public let recordType: DNSRecordType
    public let records: [String]
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        assetID: UUID,
        recordType: DNSRecordType,
        records: [String],
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        self.recordType = recordType
        self.records = records
        self.capturedAt = capturedAt
    }
}

public struct DNSDiff: Sendable {
    public let recordType: DNSRecordType
    public let added: [String]
    public let removed: [String]

    public var hasChanges: Bool { !added.isEmpty || !removed.isEmpty }

    public init(recordType: DNSRecordType, added: [String], removed: [String]) {
        self.recordType = recordType
        self.added = added
        self.removed = removed
    }

    public static func compare(baseline: [String], current: [String], type: DNSRecordType) -> DNSDiff {
        let baseSet = Set(baseline)
        let currSet = Set(current)
        return DNSDiff(
            recordType: type,
            added: Array(currSet.subtracting(baseSet)).sorted(),
            removed: Array(baseSet.subtracting(currSet)).sorted()
        )
    }
}
