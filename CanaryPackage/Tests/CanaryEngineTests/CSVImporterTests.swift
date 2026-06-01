import Testing
import Foundation
@testable import CanaryEngine

@Suite("CSVImporter Tests")
struct CSVImporterTests {
    /// Writes CSV content to a temp file and returns its URL, since the parser
    /// reads from disk (matching how the file picker hands it a URL).
    private func writeTempCSV(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).csv")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("Parses quoted fields with embedded commas and escaped quotes")
    func parsesQuotedFields() throws {
        let csv = [
            "name,url,notes",
            #""Acme, Inc.",https://acme.com,"He said ""hi""""#
        ].joined(separator: "\n")
        let url = try writeTempCSV(csv)
        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try CSVImporter().parseCSV(from: url)
        #expect(rows.count == 1)
        #expect(rows.first?["name"] == "Acme, Inc.")
        #expect(rows.first?["notes"] == "He said \"hi\"")
    }

    @Test("Detects Bitwarden format")
    func detectsBitwarden() throws {
        let csv = [
            "folder,favorite,type,name,notes,fields,login_uri,login_username,login_password,login_totp",
            ",,login,Acme,,,https://acme.com,alice@example.com,secret,"
        ].joined(separator: "\n")
        let url = try writeTempCSV(csv)
        defer { try? FileManager.default.removeItem(at: url) }

        let importer = CSVImporter()
        let rows = try importer.parseCSV(from: url)
        let format = importer.detectFormat(rows)
        #expect(format == .bitwarden)

        let result = importer.extractAssets(from: rows, format: format)
        #expect(result.emails == ["alice@example.com"])
        #expect(result.passwords == ["secret"])
    }

    @Test("Generic format extracts email and password, skips non-email usernames")
    func genericExtraction() throws {
        let csv = [
            "Email,Password",
            "bob@example.com,hunter2",
            "not-an-email,pw123"
        ].joined(separator: "\n")
        let url = try writeTempCSV(csv)
        defer { try? FileManager.default.removeItem(at: url) }

        let importer = CSVImporter()
        let rows = try importer.parseCSV(from: url)
        let format = importer.detectFormat(rows)
        let result = importer.extractAssets(from: rows, format: format)

        #expect(result.emails == ["bob@example.com"])
        #expect(Set(result.passwords) == ["hunter2", "pw123"])
        #expect(result.skipped == 1)
    }

    @Test("Empty or header-only CSV yields no rows")
    func emptyCSV() throws {
        let url = try writeTempCSV("email,password")
        defer { try? FileManager.default.removeItem(at: url) }

        let rows = try CSVImporter().parseCSV(from: url)
        #expect(rows.isEmpty)
    }
}
