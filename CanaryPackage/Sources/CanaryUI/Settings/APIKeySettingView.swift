import SwiftUI
import CanaryEngine

public struct APIKeySettingView: View {
    @Environment(Engine.self) private var engine

    @State private var apiKey = ""
    @State private var showKey = false
    @State private var saved = false
    @State private var saveError: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            HStack {
                Group {
                    if showKey {
                        TextField("Enter API key", text: $apiKey)
                    } else {
                        SecureField("Enter API key", text: $apiKey)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }

                Button("Save") { saveKey() }
                    .disabled(apiKey.isEmpty)
            }

            if saved {
                Text("API key saved")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.safe)
                    .transition(.opacity)
            }

            if let error = saveError {
                Text(error)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.danger)
                    .transition(.opacity)
            }

            if engine.apiKeyConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.safe)
                    Text("API key configured")
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            Link("Get an API key from haveibeenpwned.com",
                 destination: URL(string: "https://haveibeenpwned.com/API/Key")!)
                .font(Theme.captionFont)
        }
    }

    private func saveKey() {
        saveError = nil
        do {
            try engine.setAPIKey(apiKey)
            withAnimation(Theme.standardAnimation) { saved = true }
            apiKey = ""
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(Theme.standardAnimation) { saved = false }
            }
        } catch {
            withAnimation(Theme.standardAnimation) { saveError = error.localizedDescription }
        }
    }
}
