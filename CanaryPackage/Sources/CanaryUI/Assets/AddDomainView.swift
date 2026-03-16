import SwiftUI
import CanaryEngine

public struct AddDomainView: View {
    @Environment(Engine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var domain = ""
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(spacing: Theme.paddingLarge) {
            Text("Add Domain")
                .font(.headline)

            TextField("example.com", text: $domain)
                .textFieldStyle(.roundedBorder)

            Text("DNS records (A, MX, NS, TXT) will be captured as a baseline. Future scans will detect changes.")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = errorMessage {
                Text(error)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.danger)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Add") { addDomain() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValidDomain)
            }
        }
        .padding(Theme.paddingXL)
        .frame(width: 300)
    }

    private var isValidDomain: Bool {
        let pattern = #"^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$"#
        return domain.range(of: pattern, options: .regularExpression) != nil
    }

    private func addDomain() {
        do {
            try engine.addDomain(domain)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
