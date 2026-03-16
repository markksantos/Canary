import SwiftUI
import CanaryEngine

public struct AddEmailView: View {
    @Environment(Engine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(spacing: Theme.paddingLarge) {
            Text("Add Email")
                .font(.headline)

            TextField("email@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)

            if let error = errorMessage {
                Text(error)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.danger)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Add") { addEmail() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValidEmail)
            }
        }
        .padding(Theme.paddingXL)
        .frame(width: 300)
    }

    private var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func addEmail() {
        do {
            try engine.addEmail(email)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
