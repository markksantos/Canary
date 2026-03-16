import Foundation

public enum AssetKind: String, Codable, CaseIterable, Sendable {
    case email
    case password
    case domain
}

public enum AssetStatus: String, Codable, Sendable {
    case safe
    case exposed
    case unknown
}

public enum ScanState: Equatable, Sendable {
    case idle
    case scanning(progress: Double)
    case completed(Date)
    case failed(String)
}

public struct MonitoredAsset: Identifiable, Codable, Sendable {
    public let id: UUID
    public let kind: AssetKind
    public let value: String
    public let label: String
    public var status: AssetStatus
    public var lastChecked: Date?
    public var findingCount: Int
    public let dateAdded: Date

    public init(
        id: UUID = UUID(),
        kind: AssetKind,
        value: String,
        label: String,
        status: AssetStatus = .unknown,
        lastChecked: Date? = nil,
        findingCount: Int = 0,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.label = label
        self.status = status
        self.lastChecked = lastChecked
        self.findingCount = findingCount
        self.dateAdded = dateAdded
    }
}

public struct Finding: Identifiable, Codable, Sendable {
    public let id: UUID
    public let assetID: UUID
    public let source: FindingSource
    public let title: String
    public let detail: String
    public let date: Date
    public let severity: Severity

    public init(
        id: UUID = UUID(),
        assetID: UUID,
        source: FindingSource,
        title: String,
        detail: String,
        date: Date = Date(),
        severity: Severity = .medium
    ) {
        self.id = id
        self.assetID = assetID
        self.source = source
        self.title = title
        self.detail = detail
        self.date = date
        self.severity = severity
    }
}

public enum FindingSource: String, Codable, Sendable {
    case breach
    case paste
    case passwordExposure
    case dnsChange
}

public enum Severity: String, Codable, Comparable, Sendable {
    case low
    case medium
    case high
    case critical

    private var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
