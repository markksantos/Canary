import Testing
import Foundation
@testable import CanaryEngine

@Suite("DatabaseManager Tests")
struct DatabaseManagerTests {
    @Test("Round-trip: add asset, save, reopen, verify")
    func roundTrip() throws {
        let keychain = KeychainManager(service: "com.canary.test.\(UUID().uuidString)")
        let db = DatabaseManager(keychain: keychain)

        try db.open()

        let asset = MonitoredAsset(
            kind: .email,
            value: "test@example.com",
            label: "test@example.com"
        )
        try db.addAsset(asset)

        let fetched = try db.fetchAssets()
        #expect(fetched.count == 1)
        #expect(fetched.first?.value == "test@example.com")
        #expect(fetched.first?.kind == .email)
        #expect(fetched.first?.status == .unknown)

        try db.close()

        // Reopen and verify persistence
        let db2 = DatabaseManager(keychain: keychain)
        try db2.open()

        let refetched = try db2.fetchAssets()
        #expect(refetched.count == 1)
        #expect(refetched.first?.value == "test@example.com")

        try db2.close()

        // Cleanup
        try? keychain.delete(key: "database-encryption-key")
    }

    @Test("Add and fetch findings")
    func findings() throws {
        let keychain = KeychainManager(service: "com.canary.test.\(UUID().uuidString)")
        let db = DatabaseManager(keychain: keychain)

        try db.open()

        let asset = MonitoredAsset(kind: .email, value: "test@test.com", label: "test@test.com")
        try db.addAsset(asset)

        let finding = Finding(
            assetID: asset.id,
            source: .breach,
            title: "Test Breach",
            detail: "Found in test breach",
            severity: .high
        )
        try db.saveFinding(finding)

        let allFindings = try db.fetchFindings()
        #expect(allFindings.count == 1)
        #expect(allFindings.first?.title == "Test Breach")

        let assetFindings = try db.fetchFindings(forAsset: asset.id)
        #expect(assetFindings.count == 1)

        try db.close()
        try? keychain.delete(key: "database-encryption-key")
    }

    @Test("Remove asset")
    func removeAsset() throws {
        let keychain = KeychainManager(service: "com.canary.test.\(UUID().uuidString)")
        let db = DatabaseManager(keychain: keychain)

        try db.open()

        let asset = MonitoredAsset(kind: .password, value: "ABCDEF", label: "Password")
        try db.addAsset(asset)
        #expect(try db.fetchAssets().count == 1)

        try db.removeAsset(id: asset.id)
        #expect(try db.fetchAssets().count == 0)

        try db.close()
        try? keychain.delete(key: "database-encryption-key")
    }

    @Test("Update asset status")
    func updateAsset() throws {
        let keychain = KeychainManager(service: "com.canary.test.\(UUID().uuidString)")
        let db = DatabaseManager(keychain: keychain)

        try db.open()

        var asset = MonitoredAsset(kind: .email, value: "test@test.com", label: "test@test.com")
        try db.addAsset(asset)

        asset.status = .exposed
        asset.lastChecked = Date()
        asset.findingCount = 3
        try db.updateAsset(asset)

        let fetched = try db.fetchAssets()
        #expect(fetched.first?.status == .exposed)
        #expect(fetched.first?.findingCount == 3)
        #expect(fetched.first?.lastChecked != nil)

        try db.close()
        try? keychain.delete(key: "database-encryption-key")
    }

    @Test("Settings save and load")
    func settings() throws {
        let keychain = KeychainManager(service: "com.canary.test.\(UUID().uuidString)")
        let db = DatabaseManager(keychain: keychain)

        try db.open()

        try db.saveSetting(key: "scan_interval", value: "3600")
        let value = try db.loadSetting(key: "scan_interval")
        #expect(value == "3600")

        let missing = try db.loadSetting(key: "nonexistent")
        #expect(missing == nil)

        try db.close()
        try? keychain.delete(key: "database-encryption-key")
    }
}
