import SwiftUI

/// Settings view for configuring providers and app preferences
struct SettingsView: View {
    @ObservedObject var usageManager: MultiProviderUsageManager
    @State private var selectedProviderId: String?

    private var selectedProvider: UsageProvider? {
        guard let id = selectedProviderId else { return nil }
        return usageManager.providers[id]
    }

    private var activeProviders: [UsageProvider] {
        usageManager.providers.values
            .filter { $0.isAuthenticated && AppSettings.shared.isProviderEnabled($0.id) }
            .sorted { ($0.name) < ($1.name) }
    }

    private var needsSetupProviders: [UsageProvider] {
        usageManager.providers.values
            .filter { !$0.isAuthenticated || !AppSettings.shared.isProviderEnabled($0.id) }
            .sorted { ($0.name) < ($1.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Active Providers Section
            if !activeProviders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Active")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("(\(activeProviders.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ForEach(activeProviders, id: \.id) { provider in
                        ProviderSettingsCard(
                            provider: provider,
                            snapshot: usageManager.snapshots[provider.id],
                            isActive: true,
                            onConfigure: { selectedProviderId = provider.id },
                            onToggleEnabled: { enabled in
                                AppSettings.shared.setProviderEnabled(provider.id, enabled: enabled)
                            }
                        )
                    }
                }
            }

            // Needs Setup Section
            if !needsSetupProviders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Needs Setup")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("(\(needsSetupProviders.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ForEach(needsSetupProviders, id: \.id) { provider in
                        ProviderSettingsCard(
                            provider: provider,
                            snapshot: nil,
                            isActive: false,
                            onConfigure: { selectedProviderId = provider.id },
                            onToggleEnabled: { enabled in
                                AppSettings.shared.setProviderEnabled(provider.id, enabled: enabled)
                            }
                        )
                    }
                }
            }

            // General Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("General")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Startup settings card
                PreferenceCard {
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
                                .fontWeight(.medium)
                            Text("Launch app automatically when you log in")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }

                // Notifications settings card
                PreferenceCard {
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
                                    .fontWeight(.medium)
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
                }

                // Keyboard Shortcut card
                PreferenceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keyboard Shortcut (Cmd+U)")
                                .font(.caption)
                                .fontWeight(.medium)
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
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .sheet(isPresented: Binding(
            get: { selectedProviderId != nil },
            set: { if !$0 { selectedProviderId = nil } }
        )) {
            if let provider = selectedProvider {
                ProviderConfigModal(provider: provider, usageManager: usageManager)
            }
        }
    }
}

// MARK: - Reusable Components

/// Reusable preference card wrapper
struct PreferenceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
    }
}

/// Compact provider card for settings - no expand/collapse, just a configure button
struct ProviderSettingsCard: View {
    let provider: UsageProvider
    let snapshot: UsageSnapshot?
    let isActive: Bool
    let onConfigure: () -> Void
    let onToggleEnabled: (Bool) -> Void
    @State private var isHovered = false

    private var statusColor: Color {
        switch provider.authState {
        case .notConfigured:
            return .orange
        case .validating:
            return .blue
        case .authenticated:
            return .green
        case .failed:
            return .red
        }
    }

    private var primaryPercentage: Int? {
        guard let snapshot = snapshot else { return nil }
        let preferredId = AppSettings.shared.getPreferredQuotaId(for: provider.id)
        if let quota = snapshot.preferredQuota(quotaId: preferredId) {
            return Int(quota.computedPercentage)
        }
        return Int(snapshot.maxUsagePercentage)
    }

    var body: some View {
        Button(action: onConfigure) {
            HStack(spacing: 10) {
                // Provider icon with brand color
                Image(systemName: provider.displayConfig.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? Color(hex: provider.displayConfig.primaryColor) : Color.secondary)
                    .frame(width: 20)

                // Provider name
                Text(provider.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .primary : .secondary)

                // Percentage badge when provider has data
                if let percentage = primaryPercentage {
                    PercentageBadge(
                        percentage: percentage,
                        color: Color(hex: provider.displayConfig.primaryColor)
                    )
                }

                Spacer()

                // Status indicator for active providers
                if isActive {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)

                    // Gear icon (visual affordance only)
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    // Set Up label for inactive providers
                    Text("Set Up")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05))
            )
            .overlay(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isHovered ? Color(hex: provider.displayConfig.primaryColor).opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                Color.secondary.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}


// MARK: - Provider Configuration Modal

/// Modal for configuring a provider's credentials
struct ProviderConfigModal: View {
    let provider: UsageProvider
    @ObservedObject var usageManager: MultiProviderUsageManager
    @Environment(\.dismiss) var dismiss

    @State private var credentialInput: String = ""
    @State private var isConfiguring: Bool = false
    @State private var statusMessage: String?
    @State private var isError: Bool = false
    @State private var hasExistingCredentials: Bool = false
    @State private var isEnabled: Bool = true
    @State private var selectedQuotaId: String = "session"

    private var inputLabel: String {
        switch provider.authMethod {
        case .cookie:
            return "Session Cookie"
        case .apiKey:
            return "API Key"
        case .bearerToken:
            return "Bearer Token"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: provider.displayConfig.iconName)
                        .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                        .font(.title3)

                    Text(provider.name)
                        .font(.headline)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: provider.displayConfig.primaryColor).opacity(0.05))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(6)

                    // Show enable toggle only when configured
                    if provider.isAuthenticated {
                        Toggle(isOn: $isEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show in dashboard")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Display this provider in the Overview tab")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: isEnabled) { newValue in
                            AppSettings.shared.setProviderEnabled(provider.id, enabled: newValue)
                        }

                        // Quota display preference (show if provider has multiple quotas)
                        if let snapshot = usageManager.snapshots[provider.id], snapshot.quotas.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Show in menu bar")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("Which quota to display in the menu bar and overview")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Picker("", selection: $selectedQuotaId) {
                                    Text("Auto (highest)").tag("auto")
                                    ForEach(snapshot.quotas) { quota in
                                        Text(quota.name).tag(quota.id)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .onChange(of: selectedQuotaId) { newValue in
                                    AppSettings.shared.setPreferredQuotaId(newValue == "auto" ? nil : newValue, for: provider.id)
                                }
                            }
                        }
                    }

                    // Handle no-auth case
                    if provider.authMethod == .none {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No configuration needed for this provider")
                                .font(.caption)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        // Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to get your \(inputLabel.lowercased()):")
                                .font(.caption)
                                .fontWeight(.semibold)

                            ForEach(Array(provider.credentialInstructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 18, alignment: .trailing)

                                    Text(instruction)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)

                        // Credential input
                        VStack(alignment: .leading, spacing: 8) {
                            Text(inputLabel)
                                .font(.caption)
                                .fontWeight(.medium)

                            switch provider.authMethod {
                            case .cookie, .bearerToken:
                                TextEditor(text: $credentialInput)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                    .overlay(
                                        Group {
                                            if credentialInput.isEmpty {
                                                Text(inputPlaceholder)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(.secondary.opacity(0.5))
                                                    .padding(.leading, 4)
                                                    .padding(.top, 8)
                                            }
                                        },
                                        alignment: .topLeading
                                    )

                            case .apiKey:
                                SecureField(inputPlaceholder, text: $credentialInput)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textFieldStyle(.roundedBorder)

                            case .none:
                                EmptyView()
                            }

                            // Existing credentials hint
                            if hasExistingCredentials && statusMessage == nil {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    Text("Credentials saved. Paste new value to update.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Status message
                            if let message = statusMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(isError ? .red : .green)
                            }

                            // Credential action buttons
                            HStack(spacing: 8) {
                                Button("Save") {
                                    saveCredentialsOnly()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(credentialInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || credentialInput.hasSuffix("...") || credentialInput.contains("•"))

                                Button("Test Connection") {
                                    testConnection()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(!hasExistingCredentials && (credentialInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || credentialInput.hasSuffix("...") || credentialInput.contains("•")))

                                if isConfiguring {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            // Footer actions
            HStack {
                if provider.isAuthenticated {
                    Button("Clear Credentials") {
                        clearCredentials()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
        }
        .frame(width: 420, height: 520)
        .onAppear {
            loadExistingCredentials()
            isEnabled = AppSettings.shared.isProviderEnabled(provider.id)
            selectedQuotaId = AppSettings.shared.getPreferredQuotaId(for: provider.id) ?? "auto"
        }
    }

    private var statusColor: Color {
        switch provider.authState {
        case .notConfigured:
            return .orange
        case .validating:
            return .blue
        case .authenticated:
            return .green
        case .failed:
            return .red
        }
    }

    private var statusText: String {
        switch provider.authState {
        case .notConfigured:
            return "Not configured"
        case .validating:
            return "Validating..."
        case .authenticated:
            return "Connected"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    private func loadExistingCredentials() {
        guard credentialInput.isEmpty && !hasExistingCredentials else { return }

        if let credentials = CredentialManager.shared.load(for: provider.id) {
            switch provider.authMethod {
            case .cookie:
                if let cookie = credentials.cookie, !cookie.isEmpty {
                    hasExistingCredentials = true
                    credentialInput = String(cookie.prefix(40)) + "..."
                }
            case .apiKey:
                if let apiKey = credentials.apiKey, !apiKey.isEmpty {
                    hasExistingCredentials = true
                    credentialInput = String(repeating: "•", count: min(apiKey.count, 24))
                }
            case .bearerToken:
                if let token = credentials.bearerToken, !token.isEmpty {
                    hasExistingCredentials = true
                    credentialInput = String(token.prefix(30)) + "..."
                }
            case .none:
                break
            }
        }
    }

    private func buildCredentials(from value: String) -> ProviderCredentials {
        switch provider.authMethod {
        case .cookie:
            return ProviderCredentials(providerId: provider.id, cookie: value)
        case .apiKey:
            return ProviderCredentials(providerId: provider.id, apiKey: value)
        case .bearerToken:
            return ProviderCredentials(providerId: provider.id, bearerToken: value)
        case .none:
            return ProviderCredentials(providerId: provider.id)
        }
    }

    private func saveCredentialsOnly() {
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

        let credentials = buildCredentials(from: value)
        do {
            try CredentialManager.shared.save(credentials)
            statusMessage = "Credentials saved"
            isError = false
            hasExistingCredentials = true
        } catch {
            statusMessage = "Failed to save: \(error.localizedDescription)"
            isError = true
        }
    }

    private func testConnection() {
        let value = credentialInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // If there's new input, save it first
        let hasNewInput = !value.isEmpty && !value.hasSuffix("...") && !value.contains("•")
        if hasNewInput {
            let credentials = buildCredentials(from: value)
            do {
                try CredentialManager.shared.save(credentials)
                hasExistingCredentials = true
            } catch {
                statusMessage = "Failed to save: \(error.localizedDescription)"
                isError = true
                return
            }
        }

        // Must have saved credentials to test
        guard hasExistingCredentials else {
            statusMessage = "No credentials to test"
            isError = true
            return
        }

        isConfiguring = true
        statusMessage = nil
        isError = false

        Task {
            do {
                // Load saved credentials and configure provider
                guard let credentials = CredentialManager.shared.load(for: provider.id) else {
                    await MainActor.run {
                        isConfiguring = false
                        statusMessage = "No saved credentials found"
                        isError = true
                    }
                    return
                }

                try await provider.configure(credentials: credentials)
                await MainActor.run {
                    isConfiguring = false
                    statusMessage = "Connected successfully!"
                    isError = false
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

    private func clearCredentials() {
        provider.clearCredentials()
        credentialInput = ""
        hasExistingCredentials = false
        statusMessage = "Credentials cleared"
        isError = false
    }
}
