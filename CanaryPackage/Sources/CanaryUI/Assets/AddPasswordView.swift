import SwiftUI
import CanaryEngine

public struct AddPasswordView: View {
    @Environment(Engine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: Theme.paddingLarge) {
            Text("Check Password")
                .font(.headline)

            SecureField("Enter password to check", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)

            Text("Your password is hashed locally using SHA-1 and only the first 5 characters of the hash are sent to the API (k-anonymity). The plaintext is never stored or transmitted.")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = errorMessage {
                Text(error)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.danger)
                    .transition(.opacity)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Check") { addPassword() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(Theme.paddingXL)
        .frame(width: Theme.modalWidth)
        .onAppear { fieldFocused = true }
    }

    private func addPassword() {
        do {
            try engine.addPassword(password)
            password = "" // Clear immediately
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
