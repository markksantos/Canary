import Foundation
import Testing
@testable import CanaryEngine

@Suite("PasswordHasher Tests")
struct PasswordHasherTests {
    @Test("SHA-1 hash of 'password' matches known vector")
    func hashPassword() {
        let hash = PasswordHasher.sha1Hash(of: "password")
        #expect(hash == "5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8")
    }

    @Test("SHA-1 hash of empty string")
    func hashEmpty() {
        let hash = PasswordHasher.sha1Hash(of: "")
        #expect(hash == "DA39A3EE5E6B4B0D3255BFEF95601890AFD80709")
    }

    @Test("Split hash produces 5-char prefix and remaining suffix")
    func splitHash() {
        let (prefix, suffix) = PasswordHasher.splitHash(of: "password")
        #expect(prefix == "5BAA6")
        #expect(suffix == "1E4C9B93F3F0682250B6CF8331B7EE68FD8")
        #expect(prefix.count == 5)
        #expect(suffix.count == 35)
    }

    @Test("Hash is uppercase hex")
    func hashFormat() {
        let hash = PasswordHasher.sha1Hash(of: "test123")
        let validChars = CharacterSet(charactersIn: "0123456789ABCDEF")
        #expect(hash.unicodeScalars.allSatisfy { validChars.contains($0) })
        #expect(hash.count == 40)
    }

    @Test("Different passwords produce different hashes")
    func differentPasswords() {
        let hash1 = PasswordHasher.sha1Hash(of: "password1")
        let hash2 = PasswordHasher.sha1Hash(of: "password2")
        #expect(hash1 != hash2)
    }
}
