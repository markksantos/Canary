import Foundation
import CryptoKit

public enum PasswordHasher {
    /// Hashes a password using SHA-1 for HIBP k-anonymity checks.
    /// Returns uppercase hex string. Zeroes the plaintext bytes after hashing.
    public static func sha1Hash(of password: String) -> String {
        var bytes = Array(password.utf8)
        defer {
            for i in bytes.indices {
                bytes[i] = 0
            }
        }
        let digest = Insecure.SHA1.hash(data: bytes)
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    /// Returns (prefix, suffix) for k-anonymity range query.
    /// Prefix is first 5 chars, suffix is the rest.
    public static func splitHash(of password: String) -> (prefix: String, suffix: String) {
        let hash = sha1Hash(of: password)
        let prefixEnd = hash.index(hash.startIndex, offsetBy: 5)
        return (String(hash[..<prefixEnd]), String(hash[prefixEnd...]))
    }
}
