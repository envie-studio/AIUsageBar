import SwiftUI

/// Settings view for configuring providers and app preferences
struct SettingsView: View {
    @ObservedObject var usageManager: MultiProviderUsageManager
    @State private var expandedProviderId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Provider Configuration
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Providers")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Click to configure")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                ForEach(Array(usageManager.providers.values), id: \.id) { provider in
                    ProviderSettingsCard(
                        provider: provider,
                        isExpanded: expandedProviderId == provider.id,
                        isEnabled: AppSettings.shared.isProviderEnabled(provider.id),
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedProviderId == provider.id {
                                    expandedProviderId = nil
                                } else {
                                    expandedProviderId = provider.id
                                }
                            }
                        },
                        onToggleEnabled: { enabled in
                            AppSettings.shared.setProviderEnabled(provider.id, enabled: enabled)
                        },
                        usageManager: usageManager
                    )
                }
            }

            Divider()

            // Primary Provider Selection (only show if multiple providers are connected)
            let connectedProviders = usageManager.providers.values.filter { $0.isAuthenticated }
            if connectedProviders.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Menu Bar Display")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Picker("", selection: Binding(
                        get: { AppSettings.shared.primaryProviderId ?? "claude" },
                        set: { AppSettings.shared.primaryProviderId = $0 }
                    )) {
                        ForEach(Array(connectedProviders), id: \.id) { provider in
                            Text(provider.displayConfig.shortName)
                                .tag(provider.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text("Which provider to show in the menu bar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()
            }

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

/// Card-based provider settings with clear status and actions
struct ProviderSettingsCard: View {
    let provider: UsageProvider
    let isExpanded: Bool
    let isEnabled: Bool
    let onToggleExpand: () -> Void
    let onToggleEnabled: (Bool) -> Void
    @ObservedObject var usageManager: MultiProviderUsageManager

    private var statusConfig: (color: Color, icon: String, label: String, needsSetup: Bool) {
        switch provider.authState {
        case .notConfigured:
            return (.orange, "exclamationmark.circle.fill", "Needs setup", true)
        case .validating:
            return (.blue, "arrow.trianglehead.2.clockwise", "Checking...", false)
        case .authenticated:
            return (.green, "checkmark.circle.fill", "Connected", false)
        case .failed(let message):
            let shortMessage = message.count > 15 ? "Connection failed" : message
            return (.red, "xmark.circle.fill", shortMessage, true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row - always visible
            Button(action: onToggleExpand) {
                HStack(spacing: 10) {
                    // Provider icon with brand color
                    Image(systemName: provider.displayConfig.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                        .frame(width: 20)

                    // Provider name
                    Text(provider.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    // Status badge
                    HStack(spacing: 4) {
                        Image(systemName: statusConfig.icon)
                            .font(.system(size: 10))
                        Text(statusConfig.label)
                            .font(.caption2)
                    }
                    .foregroundColor(statusConfig.color)

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded configuration section
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 10)

                    // Show enable toggle only when configured
                    if provider.isAuthenticated {
                        HStack {
                            Toggle(isOn: Binding(
                                get: { isEnabled },
                                set: { onToggleEnabled($0) }
                            )) {
                                Text("Show in dashboard")
                                    .font(.caption)
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                    }

                    // Inline configuration
                    ProviderConfigInline(provider: provider, usageManager: usageManager)
                        .id("config-\(provider.id)")  // Force recreation when expanded
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isExpanded ? Color(hex: provider.displayConfig.primaryColor).opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
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

    @State private var credentialInput: String = ""
    @State private var isConfiguring: Bool = false
    @State private var statusMessage: String?
    @State private var isError: Bool = false
    @State private var hasExistingCredentials: Bool = false

    private var inputLabel: String {
        switch provider.authMethod {
        case .cookie:
            return "Session Cookie:"
        case .apiKey:
            return "API Key:"
        case .bearerToken:
            return "Bearer Token:"
        case .none:
            return ""
        }
    }

    private var inputPlaceholder: String {
        switch provider.authMethod {
        case .cookie:
            return "Paste full cookie string here..."
        case .apiKey:
            return "sk-..."
        case .bearerToken:
            return "Paste token here..."
        case .none:
            return ""
        }
    }

    private var instructionsTitle: String {
        switch provider.authMethod {
        case .cookie:
            return "How to get your session cookie:"
        case .apiKey:
            return "How to get your API key:"
        case .bearerToken:
            return "How to get your token:"
        case .none:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Handle no-auth case
            if provider.authMethod == .none {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("No configuration needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Instructions with better formatting
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(instructionsTitle)
                            .font(.caption2)
                            .fontWeight(.semibold)

                        // DevTools hint
                        if provider.authMethod == .cookie || provider.authMethod == .bearerToken {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(Array(provider.credentialInstructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)

                            Text(formatInstruction(instruction))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Credential input based on auth method
                VStack(alignment: .leading, spacing: 4) {
                    Text(inputLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    switch provider.authMethod {
                    case .cookie:
                        // TextEditor for long cookie strings
                        TextEditor(text: $credentialInput)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if credentialInput.isEmpty {
                                        Text(inputPlaceholder)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary.opacity(0.5))
                                            .padding(.leading, 4)
                                            .padding(.top, 8)
                                    }
                                },
                                alignment: .topLeading
                            )

                    case .apiKey:
                        // SecureField for API keys
                        SecureField(inputPlaceholder, text: $credentialInput)
                            .font(.system(size: 11, design: .monospaced))
                            .textFieldStyle(.roundedBorder)

                    case .bearerToken:
                        // TextEditor for JWT/bearer tokens (often long)
                        TextEditor(text: $credentialInput)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if credentialInput.isEmpty {
                                        Text(inputPlaceholder)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary.opacity(0.5))
                                            .padding(.leading, 4)
                                            .padding(.top, 8)
                                    }
                                },
                                alignment: .topLeading
                            )

                    case .none:
                        EmptyView()
                    }
                }

                // Existing credentials hint
                if hasExistingCredentials && statusMessage == nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Credentials saved. Paste new value to update.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
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
                        saveCredentials()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isConfiguring || credentialInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if provider.isAuthenticated {
                        Button("Clear") {
                            provider.clearCredentials()
                            credentialInput = ""
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
        }
        .padding(8)
        .background(Color(hex: provider.displayConfig.primaryColor).opacity(0.08))
        .cornerRadius(6)
        .task {
            loadExistingCredentials()
        }
    }

    /// Load existing credentials and show masked preview
    private func loadExistingCredentials() {
        // Only load if input is empty and we haven't already loaded
        guard credentialInput.isEmpty && !hasExistingCredentials else { return }

        NSLog("ProviderConfigInline: Loading credentials for \(provider.id)")

        if let credentials = CredentialManager.shared.load(for: provider.id) {
            NSLog("ProviderConfigInline: Found credentials for \(provider.id)")
            switch provider.authMethod {
            case .cookie:
                if let cookie = credentials.cookie, !cookie.isEmpty {
                    hasExistingCredentials = true
                    // Show truncated preview
                    let preview = String(cookie.prefix(30))
                    credentialInput = preview + "..."
                }
            case .apiKey:
                if let apiKey = credentials.apiKey, !apiKey.isEmpty {
                    hasExistingCredentials = true
                    // Show masked version
                    credentialInput = String(repeating: "•", count: min(apiKey.count, 20))
                }
            case .bearerToken:
                if let token = credentials.bearerToken, !token.isEmpty {
                    hasExistingCredentials = true
                    // Show truncated preview for JWT tokens
                    let preview = String(token.prefix(20))
                    credentialInput = preview + "..."
                }
            case .none:
                break
            }
        } else {
            NSLog("ProviderConfigInline: No credentials found for \(provider.id)")
        }
    }

    /// Format instruction text to highlight technical terms
    private func formatInstruction(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        // Highlight technical terms in monospace
        let technicalTerms = ["Cookie", "Bearer", "Network", "Headers", "Request Headers", "F12", "DevTools", "API"]
        for term in technicalTerms {
            if let range = result.range(of: term, options: .caseInsensitive) {
                result[range].font = .system(size: 10, design: .monospaced)
            }
        }
        return result
    }

    private func saveCredentials() {
        let value = credentialInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {
            statusMessage = "Input is empty"
            isError = true
            return
        }

        // Check if user is trying to save the preview/masked value
        if value.hasSuffix("...") || value.contains("•") {
            statusMessage = "Please paste the full credential value"
            isError = true
            return
        }

        isConfiguring = true
        statusMessage = nil
        isError = false
        hasExistingCredentials = false

        // Build credentials based on auth method
        var credentials = ProviderCredentials(providerId: provider.id)
        switch provider.authMethod {
        case .cookie:
            credentials = ProviderCredentials(providerId: provider.id, cookie: value)
        case .apiKey:
            credentials = ProviderCredentials(providerId: provider.id, apiKey: value)
        case .bearerToken:
            credentials = ProviderCredentials(providerId: provider.id, bearerToken: value)
        case .none:
            break
        }

        Task {
            do {
                try await provider.configure(credentials: credentials)
                await MainActor.run {
                    isConfiguring = false
                    statusMessage = "Connected successfully!"
                    isError = false
                    hasExistingCredentials = true
                    usageManager.fetchUsage()
                }
            } catch {
                await MainActor.run {
                    isConfiguring = false
                    statusMessage = error.localizedDescription
                    isError = true
                }
            }
        }
    }
}
