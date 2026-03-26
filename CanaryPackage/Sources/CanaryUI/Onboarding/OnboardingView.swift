import SwiftUI
import CanaryEngine

public struct OnboardingView: View {
    @Environment(Engine.self) private var engine
    @State private var step = 0

    // Step 1: API Key
    @State private var apiKey = ""
    @State private var showKey = false
    @State private var keySaved = false

    // Step 2: Email
    @State private var email = ""
    @State private var emailError: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, Theme.paddingLarge)

            Spacer()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: apiKeyStep
                case 2: addAssetStep
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()
        }
        .animation(Theme.springAnimation, value: step)
        .frame(width: Theme.popoverWidth, height: Theme.popoverHeight)
        .background(.ultraThinMaterial)
    }

    private var stepIndicator: some View {
        HStack(spacing: Theme.paddingMedium) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: Theme.paddingLarge) {
            Image(systemName: "bird.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome to Canary")
                .font(.title2.bold())

            Text("Monitor your emails, passwords, and domains for data breaches. Get notified when your data appears in new leaks.")
                .font(Theme.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.paddingXL)

            Button("Get Started") {
                step = 1
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(Theme.paddingLarge)
    }

    private var apiKeyStep: some View {
        VStack(spacing: Theme.paddingLarge) {
            Image(systemName: "key.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)

            Text("HIBP API Key")
                .font(.title3.bold())

            Text("An API key from Have I Been Pwned is required to check emails and pastes. Password checks work without one.")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

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
            }
            .padding(.horizontal, Theme.paddingLarge)

            if keySaved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.safe)
                    Text("API key saved")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.safe)
                }
            }

            HStack {
                Button("Save Key") {
                    do {
                        try engine.setAPIKey(apiKey)
                        apiKey = ""
                        withAnimation { keySaved = true }
                    } catch {}
                }
                .disabled(apiKey.isEmpty)

                Button("Next") {
                    step = 2
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Skip for now") {
                step = 2
            }
            .font(Theme.captionFont)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)

            Link("Get an API key from haveibeenpwned.com",
                 destination: URL(string: "https://haveibeenpwned.com/API/Key")!)
                .font(Theme.captionFont)
        }
        .padding(Theme.paddingLarge)
    }

    private var addAssetStep: some View {
        VStack(spacing: Theme.paddingLarge) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)

            Text("Add Your First Email")
                .font(.title3.bold())

            Text("Start monitoring an email address for breaches.")
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("email@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .padding(.horizontal, Theme.paddingLarge)

            if let error = emailError {
                Text(error)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.danger)
            }

            Button("Add & Finish") {
                do {
                    try engine.addEmail(email)
                } catch {
                    emailError = error.localizedDescription
                    return
                }
                do {
                    try engine.completeOnboarding()
                } catch {
                    engine.onboardingCompleted = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValidEmail)

            Button("Skip & Finish") {
                do {
                    try engine.completeOnboarding()
                } catch {
                    // Force the flag even if DB save fails
                    engine.onboardingCompleted = true
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(Theme.paddingLarge)
    }

    private var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
