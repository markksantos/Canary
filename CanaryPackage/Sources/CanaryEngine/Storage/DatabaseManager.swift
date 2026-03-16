import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class DatabaseManager {
    private var db: OpaquePointer?
    private let fileURL: URL
    private let keychain: KeychainManager
    private let formatter = ISO8601DateFormatter()

    public init(keychain: KeychainManager) {
        self.keychain = keychain
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let canaryDir = appSupport.appendingPathComponent("Canary", isDirectory: true)
        try? FileManager.default.createDirectory(at: canaryDir, withIntermediateDirectories: true)
        self.fileURL = canaryDir.appendingPathComponent("canary.db.enc")
    }

    // MARK: - Lifecycle

    public func open() throws {
        var dbPointer: OpaquePointer?
        guard sqlite3_open(":memory:", &dbPointer) == SQLITE_OK else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(dbPointer)))
        }
        self.db = dbPointer

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let encryptedData = try Data(contentsOf: fileURL)
            let key = try DatabaseEncryption.loadOrCreateKey(keychain: keychain)
            let plainData = try DatabaseEncryption.decrypt(encryptedData, using: key)

            let bufferSize = Int64(plainData.count)
            guard let buffer = sqlite3_malloc64(UInt64(bufferSize)) else {
                throw DatabaseError.deserializeFailed
            }
            plainData.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: Int(bufferSize))

            let rc = sqlite3_deserialize(
                db, "main",
                buffer.assumingMemoryBound(to: UInt8.self),
                bufferSize, bufferSize,
                UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
            )
            guard rc == SQLITE_OK else {
                throw DatabaseError.deserializeFailed
            }
        }

        try execute(Schema.createTables)
    }

    public func save() throws {
        guard let db = db else { throw DatabaseError.notOpen }

        var size: Int64 = 0
        guard let bytes = sqlite3_serialize(db, "main", &size, 0) else {
            throw DatabaseError.serializeFailed
        }
        let data = Data(bytes: bytes, count: Int(size))
        sqlite3_free(bytes)

        let key = try DatabaseEncryption.loadOrCreateKey(keychain: keychain)
        let encrypted = try DatabaseEncryption.encrypt(data, using: key)
        try encrypted.write(to: fileURL, options: .atomic)
    }

    public func close() throws {
        try save()
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // MARK: - Execute

    private func execute(_ sql: String) throws {
        guard let db = db else { throw DatabaseError.notOpen }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if rc != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseError.executeFailed(message)
        }
    }

    private func prepareStatement(_ sql: String) throws -> OpaquePointer {
        guard let db = db else { throw DatabaseError.notOpen }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        return stmt!
    }

    // MARK: - Assets CRUD

    public func addAsset(_ asset: MonitoredAsset) throws {
        let sql = """
            INSERT INTO monitored_assets (id, kind, value, label, status, last_checked, finding_count, date_added)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, asset.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, asset.kind.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, asset.value, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, asset.label, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, asset.status.rawValue, -1, SQLITE_TRANSIENT)
        if let lastChecked = asset.lastChecked {
            sqlite3_bind_text(stmt, 6, formatter.string(from: lastChecked), -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_int(stmt, 7, Int32(asset.findingCount))
        sqlite3_bind_text(stmt, 8, formatter.string(from: asset.dateAdded), -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db!)))
        }
    }

    public func removeAsset(id: UUID) throws {
        let sql = "DELETE FROM monitored_assets WHERE id = ?"
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db!)))
        }
    }

    public func updateAsset(_ asset: MonitoredAsset) throws {
        let sql = """
            UPDATE monitored_assets SET status = ?, last_checked = ?, finding_count = ?
            WHERE id = ?
            """
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, asset.status.rawValue, -1, SQLITE_TRANSIENT)
        if let lastChecked = asset.lastChecked {
            sqlite3_bind_text(stmt, 2, formatter.string(from: lastChecked), -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 2)
        }
        sqlite3_bind_int(stmt, 3, Int32(asset.findingCount))
        sqlite3_bind_text(stmt, 4, asset.id.uuidString, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db!)))
        }
    }

    public func fetchAssets() throws -> [MonitoredAsset] {
        let sql = "SELECT id, kind, value, label, status, last_checked, finding_count, date_added FROM monitored_assets ORDER BY date_added DESC"
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        var assets: [MonitoredAsset] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))!
            let kind = AssetKind(rawValue: String(cString: sqlite3_column_text(stmt, 1)))!
            let value = String(cString: sqlite3_column_text(stmt, 2))
            let label = String(cString: sqlite3_column_text(stmt, 3))
            let status = AssetStatus(rawValue: String(cString: sqlite3_column_text(stmt, 4)))!
            let lastChecked: Date? = sqlite3_column_type(stmt, 5) != SQLITE_NULL
                ? formatter.date(from: String(cString: sqlite3_column_text(stmt, 5)))
                : nil
            let findingCount = Int(sqlite3_column_int(stmt, 6))
            let dateAdded = formatter.date(from: String(cString: sqlite3_column_text(stmt, 7))) ?? Date()

            assets.append(MonitoredAsset(
                id: id, kind: kind, value: value, label: label,
                status: status, lastChecked: lastChecked,
                findingCount: findingCount, dateAdded: dateAdded
            ))
        }
        return assets
    }

    // MARK: - Findings CRUD

    public func saveFinding(_ finding: Finding) throws {
        let sql = """
            INSERT OR IGNORE INTO findings (id, asset_id, source, title, detail, date, severity)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, finding.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, finding.assetID.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, finding.source.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, finding.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, finding.detail, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, formatter.string(from: finding.date), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, finding.severity.rawValue, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db!)))
        }
    }

    public func fetchFindings(forAsset assetID: UUID? = nil) throws -> [Finding] {
        let sql: String
        if let assetID = assetID {
            sql = "SELECT id, asset_id, source, title, detail, date, severity FROM findings WHERE asset_id = '\(assetID.uuidString)' ORDER BY date DESC"
        } else {
            sql = "SELECT id, asset_id, source, title, detail, date, severity FROM findings ORDER BY date DESC"
        }

        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        var findings: [Finding] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))!
            let assetID = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1)))!
            let source = FindingSource(rawValue: String(cString: sqlite3_column_text(stmt, 2)))!
            let title = String(cString: sqlite3_column_text(stmt, 3))
            let detail = String(cString: sqlite3_column_text(stmt, 4))
            let date = formatter.date(from: String(cString: sqlite3_column_text(stmt, 5))) ?? Date()
            let severity = Severity(rawValue: String(cString: sqlite3_column_text(stmt, 6))) ?? .medium

            findings.append(Finding(
                id: id, assetID: assetID, source: source,
                title: title, detail: detail, date: date, severity: severity
            ))
        }
        return findings
    }

    // MARK: - DNS Baselines

    public func saveBaseline(_ baseline: DNSBaseline) throws {
        let sql = """
            INSERT OR REPLACE INTO dns_baselines (id, asset_id, record_type, records, captured_at)
            VALUES (?, ?, ?, ?, ?)
            """
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        let recordsJSON = try JSONEncoder().encode(baseline.records)
        let recordsString = String(data: recordsJSON, encoding: .utf8) ?? "[]"

        sqlite3_bind_text(stmt, 1, baseline.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, baseline.assetID.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, baseline.recordType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, recordsString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, formatter.string(from: baseline.capturedAt), -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db!)))
        }
    }

    public func fetchBaselines(forAsset assetID: UUID) throws -> [DNSBaseline] {
        let sql = "SELECT id, asset_id, record_type, records, captured_at FROM dns_baselines WHERE asset_id = ?"
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, assetID.uuidString, -1, SQLITE_TRANSIENT)

        var baselines: [DNSBaseline] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))!
            let aid = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1)))!
            let recordType = DNSRecordType(rawValue: String(cString: sqlite3_column_text(stmt, 2)))!
            let recordsStr = String(cString: sqlite3_column_text(stmt, 3))
            let records = (try? JSONDecoder().decode([String].self, from: recordsStr.data(using: .utf8)!)) ?? []
            let capturedAt = formatter.date(from: String(cString: sqlite3_column_text(stmt, 4))) ?? Date()

            baselines.append(DNSBaseline(
                id: id, assetID: aid, recordType: recordType,
                records: records, capturedAt: capturedAt
            ))
        }
        return baselines
    }

    // MARK: - Settings

    public func saveSetting(key: String, value: String) throws {
        let sql = "INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)"
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, value, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db!)))
        }
    }

    public func loadSetting(key: String) throws -> String? {
        let sql = "SELECT value FROM app_settings WHERE key = ?"
        let stmt = try prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }
        return nil
    }
}

public enum DatabaseError: LocalizedError {
    case openFailed(String)
    case notOpen
    case prepareFailed(String)
    case executeFailed(String)
    case serializeFailed
    case deserializeFailed

    public var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "DB open failed: \(m)"
        case .notOpen: return "Database not open"
        case .prepareFailed(let m): return "Prepare failed: \(m)"
        case .executeFailed(let m): return "Execute failed: \(m)"
        case .serializeFailed: return "DB serialize failed"
        case .deserializeFailed: return "DB deserialize failed"
        }
    }
}
