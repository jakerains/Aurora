import SwiftUI

private enum OnboardingMode: String, CaseIterable, Identifiable {
    case manual
    case oauth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return "Manual API Key"
        case .oauth: return "OAuth PKCE"
        }
    }
}

struct OnboardingView: View {
    private enum Field: Hashable {
        case manualKey
        case oauthBootstrap
        case oauthCallback
        case oauthCode
    }

    @Bindable var appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var mode: OnboardingMode = .manual
    @State private var manualKeyInput = ""
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connect OpenRouter")
                .font(.largeTitle.bold())

            Picker("Connection Method", selection: $mode) {
                ForEach(OnboardingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .manual:
                manualSection
            case .oauth:
                oauthSection
            }

            if let error = appState.onboardingError {
                Text(error)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.glass)

                Spacer()
            }
        }
        .padding(28)
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            setInitialFocus()
        }
        .onChange(of: mode) {
            setInitialFocus()
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste your OpenRouter API key. It is stored in Keychain.")
                .foregroundStyle(.secondary)

            SecureField("sk-or-v1-...", text: $manualKeyInput)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .manualKey)

            HStack {
                Button("Save API Key") {
                    appState.saveManualAPIKey(manualKeyInput)
                    if !appState.isOnboardingPresented {
                        dismiss()
                    }
                }
                .buttonStyle(.glassProminent)

                Spacer()
            }
        }
    }

    private var oauthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OAuth requires a bootstrap API key used for PKCE code creation/exchange.")
                .foregroundStyle(.secondary)

            SecureField("Bootstrap API key", text: $appState.oauthBootstrapKeyInput)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .oauthBootstrap)

            Button("Save Bootstrap Key") {
                appState.saveOAuthBootstrapKey()
            }
            .buttonStyle(.glass)

            TextField("Callback URL", text: $appState.oauthCallbackURLInput)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .oauthCallback)

            Button("Begin OAuth in Browser") {
                Task { await appState.beginOAuth() }
            }
            .buttonStyle(.glassProminent)

            TextField("Paste authorization code", text: $appState.oauthCodeInput)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .oauthCode)

            Button("Exchange Code and Connect") {
                Task {
                    await appState.exchangeOAuthCode()
                    if !appState.isOnboardingPresented {
                        dismiss()
                    }
                }
            }
            .buttonStyle(.glass)
        }
    }

    private func setInitialFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch mode {
            case .manual:
                focusedField = .manualKey
            case .oauth:
                focusedField = .oauthBootstrap
            }
        }
    }
}
