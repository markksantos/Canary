import SwiftUI
import CanaryEngine
import UniformTypeIdentifiers

public struct CSVImportView: View {
    @Environment(Engine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var phase: ImportPhase = .selectFile
    @State private var previewResult: CSVImportResult?
    @State private var importResult: CSVImportResult?
    @State private var errorMessage: String?
    @State private var importEmails = true
    @State private var importPasswords = true
    @State private var detectedFormat: CSVImporter.CSVFormat = .generic

    enum ImportPhase { case selectFile, preview, result }

    public init() {}

    public var body: some View {
        VStack(spacing: Theme.paddingLarge) {
            switch phase {
            case .selectFile:
                selectFileView
            case .preview:
                previewView
            case .result:
                resultView
            }
        }
        .padding(Theme.paddingXL)
        .frame(width: Theme.modalWidth + 40)
    }

    private var selectFileView: some View {
        VStack(spacing: Theme.paddingLarge) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundStyle(.tint)

            Text("Import from CSV")
                .font(.headline)

            Text("Supports 1Password, Bitwarden, Safari, and generic CSV exports.")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = errorMessage {
                Text(error)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.danger)
            }

            Button("Choose File...") { chooseFile() }
                .buttonStyle(.borderedProminent)

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var previewView: some View {
        VStack(spacing: Theme.paddingLarge) {
            Text("Import Preview")
                .font(.headline)

            if let result = previewResult {
                Text("Format detected: \(detectedFormat.rawValue)")
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: Theme.paddingMedium) {
                    Toggle("\(result.emails.count) emails", isOn: $importEmails)
                    Toggle("\(result.passwords.count) passwords", isOn: $importPasswords)
                }

                if result.skipped > 0 {
                    Text("\(result.skipped) non-email usernames skipped")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Import") { performImport() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!importEmails && !importPasswords)
            }
        }
    }

    private var resultView: some View {
        VStack(spacing: Theme.paddingLarge) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.safe)

            Text("Import Complete")
                .font(.headline)

            if let result = importResult {
                VStack(spacing: Theme.paddingSmall) {
                    if result.importedEmails > 0 {
                        Text("\(result.importedEmails) emails imported")
                            .font(Theme.bodyFont)
                    }
                    if result.importedPasswords > 0 {
                        Text("\(result.importedPasswords) passwords imported")
                            .font(Theme.bodyFont)
                    }
                    if result.duplicates > 0 {
                        Text("\(result.duplicates) duplicates skipped")
                            .font(Theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType(filenameExtension: "csv")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let importer = CSVImporter()
            let rows = try importer.parseCSV(from: url)
            detectedFormat = importer.detectFormat(rows)
            previewResult = importer.extractAssets(from: rows, format: detectedFormat)
            phase = .preview
        } catch {
            errorMessage = "Failed to parse CSV: \(error.localizedDescription)"
        }
    }

    private func performImport() {
        guard let result = previewResult else { return }

        let emails = importEmails ? result.emails : []
        let passwords = importPasswords ? result.passwords : []

        var importedEmails = 0
        var importedPasswords = 0
        var duplicates = 0

        for email in emails {
            do {
                try engine.addEmail(email)
                importedEmails += 1
            } catch {
                duplicates += 1
            }
        }
        for password in passwords {
            do {
                try engine.addPassword(password)
                importedPasswords += 1
            } catch {
                duplicates += 1
            }
        }

        importResult = CSVImportResult(
            emails: emails,
            passwords: passwords,
            importedEmails: importedEmails,
            importedPasswords: importedPasswords,
            skipped: result.skipped,
            duplicates: duplicates
        )
        phase = .result
    }
}
