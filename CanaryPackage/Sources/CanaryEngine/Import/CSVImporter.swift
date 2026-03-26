import Foundation

public struct CSVImportResult: Sendable {
    public let emails: [String]
    public let passwords: [String]
    public let importedEmails: Int
    public let importedPasswords: Int
    public let skipped: Int
    public let duplicates: Int

    public init(emails: [String], passwords: [String], importedEmails: Int = 0,
                importedPasswords: Int = 0, skipped: Int = 0, duplicates: Int = 0) {
        self.emails = emails
        self.passwords = passwords
        self.importedEmails = importedEmails
        self.importedPasswords = importedPasswords
        self.skipped = skipped
        self.duplicates = duplicates
    }
}

public struct CSVImporter {
    public enum CSVFormat: String, Sendable {
        case onePassword = "1Password"
        case bitwarden = "Bitwarden"
        case safari = "Safari"
        case generic = "Generic"
    }

    public init() {}

    public func parseCSV(from url: URL) throws -> [[String: String]] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return [] }

        let headers = parseCSVLine(lines[0])
        var rows: [[String: String]] = []

        for i in 1..<lines.count {
            let fields = parseCSVLine(lines[i])
            guard fields.count == headers.count else { continue }
            var row: [String: String] = [:]
            for (j, header) in headers.enumerated() {
                row[header] = fields[j]
            }
            rows.append(row)
        }

        return rows
    }

    public func detectFormat(_ rows: [[String: String]]) -> CSVFormat {
        guard let first = rows.first else { return .generic }
        let keys = Set(first.keys.map { $0.lowercased() })

        if keys.contains("login_uri") || keys.contains("login_username") {
            return .bitwarden
        }
        if keys.contains("username") && keys.contains("password") && keys.contains("url") {
            if keys.contains("otpauth") { return .safari }
            return .onePassword
        }
        return .generic
    }

    public func extractAssets(from rows: [[String: String]], format: CSVFormat) -> CSVImportResult {
        var emails: [String] = []
        var passwords: [String] = []
        var skipped = 0

        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

        for row in rows {
            let (username, password) = extractCredentials(from: row, format: format)

            if let username = username, !username.isEmpty {
                if username.range(of: emailPattern, options: .regularExpression) != nil {
                    emails.append(username)
                } else {
                    skipped += 1
                }
            }

            if let password = password, !password.isEmpty {
                passwords.append(password)
            }
        }

        return CSVImportResult(
            emails: Array(Set(emails)),
            passwords: Array(Set(passwords)),
            skipped: skipped
        )
    }

    private func extractCredentials(from row: [String: String], format: CSVFormat) -> (String?, String?) {
        switch format {
        case .bitwarden:
            return (row["login_username"], row["login_password"])
        case .safari:
            return (row["Username"], row["Password"])
        case .onePassword:
            return (row["username"] ?? row["Username"], row["password"] ?? row["Password"])
        case .generic:
            let username = row.first(where: { k, _ in
                let lower = k.lowercased()
                return lower.contains("email") || lower.contains("username") || lower.contains("login")
            })?.value
            let password = row.first(where: { k, _ in
                k.lowercased().contains("password")
            })?.value
            return (username, password)
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var chars = line.makeIterator()

        while let char = chars.next() {
            if inQuotes {
                if char == "\"" {
                    if let next = chars.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                fields.append(current)
                                current = ""
                            } else {
                                current.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
        }
        fields.append(current)
        return fields
    }
}
