import Foundation

@Observable
public final class Engine {
    // MARK: - Published State
    public var assets: [MonitoredAsset] = []
    public var recentFindings: [Finding] = []
    public var scanState: ScanState = .idle
    public var apiKeyConfigured: Bool = false
    public var errorMessage: String?

    public var overallStatus: AssetStatus {
        if assets.isEmpty { return .unknown }
        if assets.contains(where: { $0.status == .exposed }) { return .exposed }
        if assets.allSatisfy({ $0.status == .safe }) { return .safe }
        return .unknown
    }

    public var isScanning: Bool {
        if case .scanning = scanState { return true }
        return false
    }

    // MARK: - Services
    public let keychain: KeychainManager
    public let database: DatabaseManager
    public let hibpClient: HIBPClient
    public let dnsMonitor: DNSMonitor
    public let notificationManager: NotificationManager
    public let scheduler: ScanScheduler

    private static let apiKeyName = "hibp-api-key"

    public init() {
        let kc = KeychainManager()
        self.keychain = kc
        self.database = DatabaseManager(keychain: kc)
        self.dnsMonitor = DNSMonitor()
        self.notificationManager = NotificationManager()

        self.hibpClient = HIBPClient(apiKeyProvider: { [kc] in
            try? kc.loadString(forKey: Engine.apiKeyName)
        })

        var scanRef: (() async -> Void)?
        self.scheduler = ScanScheduler { await scanRef?() }
        scanRef = { [weak self] in await self?.runFullScan() }
    }

    // MARK: - Lifecycle

    public func start() async {
        do {
            try database.open()
            assets = try database.fetchAssets()
            recentFindings = try database.fetchFindings()
            apiKeyConfigured = (try? keychain.loadString(forKey: Engine.apiKeyName)) != nil
            _ = await notificationManager.requestAuthorization()
            notificationManager.registerCategories()
            scheduler.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func shutdown() {
        scheduler.stop()
        try? database.close()
    }

    // MARK: - API Key

    public func setAPIKey(_ key: String) throws {
        if key.isEmpty {
            try keychain.delete(key: Engine.apiKeyName)
            apiKeyConfigured = false
        } else {
            try keychain.saveString(key, forKey: Engine.apiKeyName)
            apiKeyConfigured = true
        }
    }

    // MARK: - Asset Management

    public func addEmail(_ email: String) throws {
        let asset = MonitoredAsset(kind: .email, value: email, label: email)
        try database.addAsset(asset)
        assets.insert(asset, at: 0)
    }

    public func addPassword(_ password: String) throws {
        let hash = PasswordHasher.sha1Hash(of: password)
        let asset = MonitoredAsset(kind: .password, value: hash, label: "Password (\(hash.prefix(8))...)")
        try database.addAsset(asset)
        assets.insert(asset, at: 0)
    }

    public func addDomain(_ domain: String) throws {
        let asset = MonitoredAsset(kind: .domain, value: domain, label: domain)
        try database.addAsset(asset)
        assets.insert(asset, at: 0)
    }

    public func removeAsset(_ asset: MonitoredAsset) throws {
        try database.removeAsset(id: asset.id)
        assets.removeAll { $0.id == asset.id }
        recentFindings.removeAll { $0.assetID == asset.id }
    }

    // MARK: - Scanning

    public func runFullScan() async {
        guard !isScanning else { return }
        scanState = .scanning(progress: 0)
        errorMessage = nil

        let total = Double(assets.count)
        var newFindings: [Finding] = []

        for (index, asset) in assets.enumerated() {
            if Task.isCancelled { break }
            scanState = .scanning(progress: Double(index) / max(total, 1))

            do {
                let findings = try await scanAsset(asset)
                newFindings.append(contentsOf: findings)

                var updated = asset
                updated.lastChecked = Date()
                updated.findingCount = (try? database.fetchFindings(forAsset: asset.id))?.count ?? 0
                updated.status = updated.findingCount > 0 ? .exposed : .safe

                try database.updateAsset(updated)
                if let idx = assets.firstIndex(where: { $0.id == asset.id }) {
                    assets[idx] = updated
                }
            } catch {
                errorMessage = "Scan error for \(asset.label): \(error.localizedDescription)"
            }
        }

        recentFindings = (try? database.fetchFindings()) ?? recentFindings
        scanState = .completed(Date())

        try? database.save()
    }

    private func scanAsset(_ asset: MonitoredAsset) async throws -> [Finding] {
        switch asset.kind {
        case .email:
            return try await scanEmail(asset)
        case .password:
            return try await scanPassword(asset)
        case .domain:
            return try await scanDomain(asset)
        }
    }

    private func scanEmail(_ asset: MonitoredAsset) async throws -> [Finding] {
        var findings: [Finding] = []

        let breaches = try await hibpClient.checkEmail(asset.value)
        for breach in breaches {
            let finding = Finding(
                assetID: asset.id,
                source: .breach,
                title: breach.title,
                detail: "Found in \(breach.name) breach (\(breach.breachDate)). \(breach.pwnCount.formatted()) accounts affected.",
                severity: breach.isVerified ? .high : .medium
            )
            try? database.saveFinding(finding)
            findings.append(finding)
            await notificationManager.sendBreachNotification(assetLabel: asset.label, breachName: breach.title)
        }

        let pastes = try await hibpClient.checkPastes(asset.value)
        for paste in pastes {
            let finding = Finding(
                assetID: asset.id,
                source: .paste,
                title: paste.title ?? "Untitled Paste",
                detail: "Found in paste on \(paste.source) (\(paste.emailCount) emails)",
                severity: .medium
            )
            try? database.saveFinding(finding)
            findings.append(finding)
            await notificationManager.sendPasteNotification(assetLabel: asset.label, source: paste.source)
        }

        return findings
    }

    private func scanPassword(_ asset: MonitoredAsset) async throws -> [Finding] {
        let count = try await hibpClient.checkPassword(sha1Hash: asset.value)

        if count > 0 {
            let finding = Finding(
                assetID: asset.id,
                source: .passwordExposure,
                title: "Password Compromised",
                detail: "This password has been seen \(count.formatted()) times in data breaches.",
                severity: count > 100 ? .critical : .high
            )
            try? database.saveFinding(finding)
            return [finding]
        }

        return []
    }

    private func scanDomain(_ asset: MonitoredAsset) async throws -> [Finding] {
        var findings: [Finding] = []
        let baselines = try database.fetchBaselines(forAsset: asset.id)

        if baselines.isEmpty {
            // First scan: capture baseline
            for type in DNSRecordType.allCases {
                let records = (try? await dnsMonitor.resolve(domain: asset.value, type: type)) ?? []
                if !records.isEmpty {
                    let baseline = DNSBaseline(assetID: asset.id, recordType: type, records: records)
                    try database.saveBaseline(baseline)
                }
            }
        } else {
            let diffs = await dnsMonitor.checkDomain(asset.value, baselines: baselines)
            for diff in diffs {
                let finding = Finding(
                    assetID: asset.id,
                    source: .dnsChange,
                    title: "\(diff.recordType.rawValue) Record Changed",
                    detail: "Added: \(diff.added.joined(separator: ", ")). Removed: \(diff.removed.joined(separator: ", ")).",
                    severity: diff.recordType == .ns ? .high : .medium
                )
                try? database.saveFinding(finding)
                findings.append(finding)
                await notificationManager.sendDNSChangeNotification(
                    domain: asset.value, recordType: diff.recordType.rawValue
                )
            }

            // Update baselines
            for type in DNSRecordType.allCases {
                let records = (try? await dnsMonitor.resolve(domain: asset.value, type: type)) ?? []
                if !records.isEmpty {
                    let baseline = DNSBaseline(assetID: asset.id, recordType: type, records: records)
                    try database.saveBaseline(baseline)
                }
            }
        }

        return findings
    }
}
