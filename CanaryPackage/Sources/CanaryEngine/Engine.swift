import Foundation
import os

@Observable
public final class Engine {
    // MARK: - Published State
    public var assets: [MonitoredAsset] = []
    public var recentFindings: [Finding] = []
    public var scanState: ScanState = .idle
    public var apiKeyConfigured: Bool = false
    public var errorMessage: String?
    public var scanHistory: [ScanLogEntry] = []
    public var newFindingsCount: Int = 0
    public var onboardingCompleted: Bool = false

    private var hasStarted = false
    private let logger = Logger(subsystem: "com.canary.app", category: "Engine")

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

    public var weeklyNewFindings: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return recentFindings.filter { $0.date > weekAgo }.count
    }

    // MARK: - Services
    public let keychain: KeychainManager
    public let database: DatabaseManager
    public let hibpClient: HIBPClient
    public let xonClient: XposedOrNotClient
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
        self.xonClient = XposedOrNotClient()

        self.hibpClient = HIBPClient(apiKeyProvider: { [kc] in
            try? kc.loadString(forKey: Engine.apiKeyName)
        })

        self.scheduler = ScanScheduler()
        self.scheduler.onScan = { [weak self] in await self?.runFullScan() }
    }

    // MARK: - Lifecycle

    public func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        logger.info("Engine starting")

        do {
            try database.open()
            assets = try database.fetchAssets()
            recentFindings = try database.fetchFindings()
            apiKeyConfigured = (try? keychain.loadString(forKey: Engine.apiKeyName)) != nil
            onboardingCompleted = (try? database.loadSetting(key: "onboardingCompleted")) == "true"
            notificationManager.configure(database: database)
            notificationManager.loadPreferences()
            scanHistory = (try? database.fetchScanLogs()) ?? []
            updateNewFindingsCount()
            _ = await notificationManager.requestAuthorization()
            notificationManager.registerCategories()
            scheduler.start()
            logger.info("Engine started with \(self.assets.count) assets")
        } catch {
            logger.error("Engine start failed: \(error.localizedDescription)")
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
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard !assets.contains(where: { $0.kind == .email && $0.value == normalized }) else {
            throw EngineError.duplicateAsset
        }
        let asset = MonitoredAsset(kind: .email, value: normalized, label: normalized)
        try database.addAsset(asset)
        assets.insert(asset, at: 0)
    }

    public func addPassword(_ password: String) throws {
        let hash = PasswordHasher.sha1Hash(of: password)
        guard !assets.contains(where: { $0.kind == .password && $0.value == hash }) else {
            throw EngineError.duplicateAsset
        }
        let asset = MonitoredAsset(kind: .password, value: hash, label: "Password (\(hash.prefix(8))...)")
        try database.addAsset(asset)
        assets.insert(asset, at: 0)
    }

    public func addDomain(_ domain: String) throws {
        let normalized = domain.lowercased().trimmingCharacters(in: .whitespaces)
        guard !assets.contains(where: { $0.kind == .domain && $0.value == normalized }) else {
            throw EngineError.duplicateAsset
        }
        let asset = MonitoredAsset(kind: .domain, value: normalized, label: normalized)
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
        logger.info("Starting full scan of \(self.assets.count) assets")

        let scanLogId = try? database.insertScanLog(startedAt: Date(), assetsScanned: assets.count)

        let total = Double(assets.count)
        var newFindings: [Finding] = []
        var scanErrors: [String] = []

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
                logger.error("Scan error for \(asset.label): \(error.localizedDescription)")
                scanErrors.append(asset.label)
            }
        }

        do {
            recentFindings = try database.fetchFindings()
        } catch {
            logger.error("Failed to refresh findings: \(error.localizedDescription)")
        }

        if let logId = scanLogId {
            let status = scanErrors.isEmpty ? "completed" : "partial"
            try? database.completeScanLog(id: logId, findingsCount: newFindings.count, status: status)
            scanHistory = (try? database.fetchScanLogs()) ?? []
        }

        updateNewFindingsCount()
        scanState = .completed(Date())

        do {
            try database.save()
        } catch {
            logger.error("Failed to save database: \(error.localizedDescription)")
            errorMessage = "Failed to save scan results"
        }

        if !scanErrors.isEmpty {
            errorMessage = "Scan errors for \(scanErrors.count) asset(s)"
        }

        logger.info("Scan complete: \(newFindings.count) findings, \(scanErrors.count) errors")
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
        var seenBreachNames: Set<String> = []

        // HIBP breach check (requires API key)
        if apiKeyConfigured {
            let breaches = try await hibpClient.checkEmail(asset.value)
            for breach in breaches {
                seenBreachNames.insert(breach.name.lowercased())
                let metadata = FindingMetadata(
                    domain: breach.domain,
                    pwnCount: breach.pwnCount,
                    dataClasses: breach.dataClasses,
                    breachDate: breach.breachDate,
                    isVerified: breach.isVerified,
                    sourceProvider: "hibp",
                    plainDetail: "Found in \(breach.name) breach (\(breach.breachDate)). \(breach.pwnCount.formatted()) accounts affected."
                )
                let detailJSON = (try? String(data: JSONEncoder().encode(metadata), encoding: .utf8)) ?? metadata.plainDetail ?? ""
                let finding = Finding(
                    assetID: asset.id,
                    source: .breach,
                    title: breach.title,
                    detail: detailJSON,
                    severity: breach.isVerified ? .high : .medium
                )
                do {
                    try database.saveFinding(finding)
                } catch {
                    logger.error("Failed to save finding: \(error.localizedDescription)")
                }
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
                do {
                    try database.saveFinding(finding)
                } catch {
                    logger.error("Failed to save finding: \(error.localizedDescription)")
                }
                findings.append(finding)
                await notificationManager.sendPasteNotification(assetLabel: asset.label, source: paste.source)
            }
        }

        // XposedOrNot check (free, no API key needed)
        do {
            let xonBreaches = try await xonClient.checkEmail(asset.value)
            for breach in xonBreaches where !seenBreachNames.contains(breach.breachName.lowercased()) {
                let metadata = FindingMetadata(
                    domain: breach.domain,
                    pwnCount: breach.exposedRecords,
                    dataClasses: breach.exposedData,
                    breachDate: breach.exposedDate,
                    isVerified: nil,
                    sourceProvider: "xposedornot",
                    plainDetail: "Found in \(breach.breachName) breach (\(breach.exposedDate)). \(breach.exposedRecords.formatted()) records exposed."
                )
                let detailJSON = (try? String(data: JSONEncoder().encode(metadata), encoding: .utf8)) ?? metadata.plainDetail ?? ""
                let finding = Finding(
                    assetID: asset.id,
                    source: .breach,
                    title: breach.breachName,
                    detail: detailJSON,
                    severity: .medium
                )
                do {
                    try database.saveFinding(finding)
                } catch {
                    logger.error("Failed to save finding: \(error.localizedDescription)")
                }
                findings.append(finding)
                await notificationManager.sendBreachNotification(assetLabel: asset.label, breachName: breach.breachName)
            }
        } catch {
            logger.warning("XposedOrNot check failed for \(asset.label): \(error.localizedDescription)")
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
            do {
                try database.saveFinding(finding)
            } catch {
                logger.error("Failed to save finding: \(error.localizedDescription)")
            }
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
                do {
                    try database.saveFinding(finding)
                } catch {
                    logger.error("Failed to save finding: \(error.localizedDescription)")
                }
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
    // MARK: - Onboarding

    public func completeOnboarding() throws {
        try database.saveSetting(key: "onboardingCompleted", value: "true")
        onboardingCompleted = true
    }

    // MARK: - Badge

    public func markFindingsViewed() {
        let now = ISO8601DateFormatter().string(from: Date())
        try? database.saveSetting(key: "lastViewedFindings", value: now)
        newFindingsCount = 0
    }

    private func updateNewFindingsCount() {
        guard let lastViewedStr = try? database.loadSetting(key: "lastViewedFindings"),
              let lastViewed = ISO8601DateFormatter().date(from: lastViewedStr) else {
            newFindingsCount = recentFindings.count
            return
        }
        newFindingsCount = recentFindings.filter { $0.date > lastViewed }.count
    }

    // MARK: - Single Asset Scan

    public func scanSingleAsset(_ asset: MonitoredAsset) async {
        guard !isScanning else { return }
        scanState = .scanning(progress: 0)
        errorMessage = nil

        do {
            let findings = try await scanAsset(asset)

            var updated = asset
            updated.lastChecked = Date()
            updated.findingCount = (try? database.fetchFindings(forAsset: asset.id))?.count ?? 0
            updated.status = updated.findingCount > 0 ? .exposed : .safe

            try database.updateAsset(updated)
            if let idx = assets.firstIndex(where: { $0.id == asset.id }) {
                assets[idx] = updated
            }

            recentFindings = try database.fetchFindings()
            updateNewFindingsCount()
            try database.save()

            logger.info("Single scan complete for \(asset.label): \(findings.count) findings")
        } catch {
            logger.error("Single scan error for \(asset.label): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        scanState = .completed(Date())
    }

    // MARK: - CSV Import

    public func importCSV(from url: URL) throws -> CSVImportResult {
        let importer = CSVImporter()
        let rows = try importer.parseCSV(from: url)
        let format = importer.detectFormat(rows)
        var result = importer.extractAssets(from: rows, format: format)

        var importedEmails = 0
        var importedPasswords = 0
        var duplicates = 0

        for email in result.emails {
            do {
                try addEmail(email)
                importedEmails += 1
            } catch {
                duplicates += 1
            }
        }
        for password in result.passwords {
            do {
                try addPassword(password)
                importedPasswords += 1
            } catch {
                duplicates += 1
            }
        }

        result = CSVImportResult(
            emails: result.emails,
            passwords: result.passwords,
            importedEmails: importedEmails,
            importedPasswords: importedPasswords,
            skipped: result.skipped,
            duplicates: duplicates
        )
        return result
    }
}

public enum EngineError: LocalizedError {
    case duplicateAsset

    public var errorDescription: String? {
        switch self {
        case .duplicateAsset: return "This asset is already being monitored"
        }
    }
}
