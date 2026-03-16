import Foundation
import CryptoKit

public enum DatabaseEncryption {
    private static let keychainKey = "database-encryption-key"

    public static func generateAndStoreKey(keychain: KeychainManager) throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try keychain.save(key: keychainKey, data: keyData)
        return key
    }

    public static func loadOrCreateKey(keychain: KeychainManager) throws -> SymmetricKey {
        if let data = try keychain.load(key: keychainKey) {
            return SymmetricKey(data: data)
        }
        return try generateAndStoreKey(keychain: keychain)
    }

    public static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    public static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

public enum EncryptionError: LocalizedError {
    case sealFailed
    case decryptFailed

    public var errorDescription: String? {
        switch self {
        case .sealFailed: return "Failed to seal encrypted data"
        case .decryptFailed: return "Failed to decrypt data"
        }
    }
}
