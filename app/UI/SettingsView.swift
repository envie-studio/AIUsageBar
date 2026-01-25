import SwiftUI

/// Settings view for configuring providers and app preferences
struct SettingsView: View {
    @ObservedObject var usageManager: MultiProviderUsageManager
    @State private var selectedProviderId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Provider Configuration
            VStack(alignment: .leading, spacing: 8) {
                Text("Providers")
                    .font(.caption)
                    .fontWeight(.semibold)

                ForEach(Array(usageManager.providers.values), id: \.id) { provider in
                    ProviderToggleRow(
                        provider: provider,
                        isEnabled: AppSettings.shared.isProviderEnabled(provider.id),
                        onToggle: { enabled in
                            AppSettings.shared.setProviderEnabled(provider.id, enabled: enabled)
                        },
                        onConfigure: {
                            if selectedProviderId == provider.id {
                                selectedProviderId = nil
                            } else {
                                selectedProviderId = provider.id
                            }
                        }
                    )

                    // Inline config when selected
                    if selectedProviderId == provider.id {
                        ProviderConfigInline(provider: provider, usageManager: usageManager)
                    }
                }
            }

            Divider()

            // Primary Provider Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu Bar Provider")
                    .font(.caption)
                    .fontWeight(.semibold)

                Picker("", selection: Binding(
                    get: { AppSettings.shared.primaryProviderId ?? "claude" },
                    set: { AppSettings.shared.primaryProviderId = $0 }
                )) {
                    ForEach(Array(usageManager.providers.values), id: \.id) { provider in
                        Text(provider.displayConfig.shortName)
                            .tag(provider.id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Shown in menu bar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // General Settings
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { usageManager.openAtLogin },
                    set: { newValue in
                        usageManager.openAtLogin = newValue
                        usageManager.saveSettings()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open at Login")
                            .font(.caption)
                        Text("Launch app automatically when you log in")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { usageManager.notificationsEnabled },
                        set: { newValue in
                            usageManager.notificationsEnabled = newValue
                            usageManager.saveSettings()
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Notifications")
                                .font(.caption)
                            Text("Get alerts at 25%, 50%, 75%, and 90%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)

                    Button("Test Notification") {
                        usageManager.sendTestNotification()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider()

                // Keyboard Shortcut
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard Shortcut (Cmd+U)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Toggle popup from anywhere")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if !usageManager.isAccessibilityEnabled {
                        Button("Enable Keyboard Shortcut") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Text("Grant Accessibility permission")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

/// Row for toggling a provider on/off
struct ProviderToggleRow: View {
    let provider: UsageProvider
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    let onConfigure: () -> Void

    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(provider.isAuthenticated ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            // Provider name
            Text(provider.name)
                .font(.caption)

            Spacer()

            // Configure button
            Button(action: onConfigure) {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            // Enable toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

/// Sheet for configuring a provider's credentials
struct ProviderConfigSheet: View {
    let provider: UsageProvider
    @ObservedObject var usageManager: MultiProviderUsageManager
    @Environment(\.dismiss) var dismiss

    @State private var cookieInput: String = ""
    @State private var apiKeyInput: String = ""
    @State private var isConfiguring: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: provider.displayConfig.iconName)
                    .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                    .font(.title2)

                Text("Configure \(provider.name)")
                    .font(.headline)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            // Status
            HStack {
                Text("Status:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                switch provider.authState {
                case .notConfigured:
                    Text("Not configured")
                        .font(.caption)
                        .foregroundColor(.orange)
                case .validating:
                    Text("Validating...")
                        .font(.caption)
                        .foregroundColor(.blue)
                case .authenticated:
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                case .failed(let message):
                    Text("Failed: \(message)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Divider()

            // Instructions
            VStack(alignment: .leading, spacing: 4) {
                Text("How to get credentials:")
                    .font(.caption)
                    .fontWeight(.semibold)

                ForEach(provider.credentialInstructions, id: \.self) { instruction in
                    Text(instruction)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Credential input
            VStack(alignment: .leading, spacing: 8) {
                switch provider.authMethod {
                case .cookie:
                    Text("Session Cookie:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $cookieInput)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 80)
                        .border(Color.secondary.opacity(0.3), width: 1)

                case .apiKey:
                    Text("API Key:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    SecureField("Enter API key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)

                case .bearerToken:
                    Text("Bearer Token:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    SecureField("Enter token", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)

                case .none:
                    Text("No authentication required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Actions
            HStack {
                Button("Save & Test") {
                    saveCredentials()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConfiguring)

                if provider.isAuthenticated {
                    Button("Clear") {
                        clearCredentials()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if isConfiguring {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding()
        .frame(width: 420, height: 480)
        .onAppear {
            loadExistingCredentials()
        }
    }

    private func loadExistingCredentials() {
        if let credentials = CredentialManager.shared.load(for: provider.id) {
            if let cookie = credentials.cookie, !cookie.isEmpty {
                cookieInput = String(cookie.prefix(50)) + "..."
            }
            if let apiKey = credentials.apiKey, !apiKey.isEmpty {
                apiKeyInput = String(repeating: "*", count: 20)
            }
        }
    }

    private func saveCredentials() {
        isConfiguring = true
        errorMessage = nil

        var credentials = ProviderCredentials(providerId: provider.id)

        switch provider.authMethod {
        case .cookie:
            credentials = ProviderCredentials(providerId: provider.id, cookie: cookieInput)
        case .apiKey:
            credentials = ProviderCredentials(providerId: provider.id, apiKey: apiKeyInput)
        case .bearerToken:
            credentials = ProviderCredentials(providerId: provider.id, bearerToken: apiKeyInput)
        case .none:
            break
        }

        Task {
            do {
                try await provider.configure(credentials: credentials)
                await MainActor.run {
                    isConfiguring = false
                    usageManager.fetchUsage()
                }
            } catch {
                await MainActor.run {
                    isConfiguring = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func clearCredentials() {
        provider.clearCredentials()
        cookieInput = ""
        apiKeyInput = ""
    }
}

/// Inline configuration view for a provider (used within the settings panel)
struct ProviderConfigInline: View {
    let provider: UsageProvider
    @ObservedObject var usageManager: MultiProviderUsageManager

    @State private var tokenInput: String = ""
    @State private var isConfiguring: Bool = false
    @State private var statusMessage: String?
    @State private var isError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Instructions
            VStack(alignment: .leading, spacing: 2) {
                Text("How to get token:")
                    .font(.caption2)
                    .fontWeight(.semibold)

                ForEach(provider.credentialInstructions, id: \.self) { instruction in
                    Text(instruction)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Token input - use TextEditor for paste support
            VStack(alignment: .leading, spacing: 4) {
                Text("Bearer Token:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                TextEditor(text: $tokenInput)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(height: 50)
                    .border(Color.secondary.opacity(0.3), width: 1)
            }

            // Status message
            if let message = statusMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(isError ? .red : .green)
            }

            // Actions
            HStack(spacing: 8) {
                Button("Save & Test") {
                    NSLog("ProviderConfigInline: Save button clicked, token length: \(tokenInput.count)")
                    saveCredentials()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isConfiguring || tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if provider.isAuthenticated {
                    Button("Clear") {
                        provider.clearCredentials()
                        tokenInput = ""
                        statusMessage = "Credentials cleared"
                        isError = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if isConfiguring {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Testing...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }

    private func saveCredentials() {
        let token = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty else {
            statusMessage = "Token is empty"
            isError = true
            return
        }

        NSLog("ProviderConfigInline: Saving token for \(provider.id), length: \(token.count)")

        isConfiguring = true
        statusMessage = nil
        isError = false

        let credentials = ProviderCredentials(providerId: provider.id, bearerToken: token)

        Task {
            do {
                NSLog("ProviderConfigInline: Calling provider.configure...")
                try await provider.configure(credentials: credentials)
                NSLog("ProviderConfigInline: Configure succeeded!")
                await MainActor.run {
                    isConfiguring = false
                    statusMessage = "Connected successfully!"
                    isError = false
                    usageManager.fetchUsage()
                }
            } catch {
                NSLog("ProviderConfigInline: Configure failed: \(error)")
                await MainActor.run {
                    isConfiguring = false
                    statusMessage = error.localizedDescription
                    isError = true
                }
            }
        }
    }
}
