import SwiftUI
import AppKit

/// Main usage display view with multi-provider support
struct MultiProviderUsageView: View {
    @ObservedObject var usageManager: MultiProviderUsageManager
    @State private var sessionCookieInput: String = ""
    @State private var showingCookieInput: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingProviderCards: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("AI Usage")
                        .font(.headline)

                    Spacer()

                    if usageManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.bottom, 4)

            // Error message
            if let error = usageManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.bottom, 8)
            }

            // Welcome message if no data
            if !usageManager.hasFetchedData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome! Configure your AI providers below to get started.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Supported providers:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    ForEach(Array(usageManager.providers.values), id: \.id) { provider in
                        HStack(spacing: 6) {
                            Image(systemName: provider.displayConfig.iconName)
                                .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                                .font(.caption)
                            Text(provider.name)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // Provider cards or legacy Claude view
            if usageManager.hasFetchedData {
                if showingProviderCards {
                    // Multi-provider view
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(usageManager.providers.values), id: \.id) { provider in
                                if provider.isAuthenticated {
                                    ProviderCardView(
                                        provider: provider,
                                        snapshot: usageManager.snapshot(for: provider.id)
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                } else {
                    // Legacy Claude-only view for backwards compatibility
                    LegacyClaudeUsageView(usageManager: usageManager)
                }

                Divider()

                // Last updated and refresh
                HStack {
                    Text("Last updated: \(formatTime(usageManager.lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(showingProviderCards ? "Simple" : "Detailed") {
                        showingProviderCards.toggle()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)

                    Button("Refresh") {
                        usageManager.fetchUsage()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            // Quick configure Claude (legacy support)
            Button(showingCookieInput ? "Hide Cookie" : "Set Session Cookie") {
                showingCookieInput.toggle()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            if showingCookieInput {
                LegacyCookieInputView(
                    sessionCookieInput: $sessionCookieInput,
                    usageManager: usageManager
                )
            }

            // Support link
            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://donate.stripe.com/3cIcN5b5H7Q8ay8bIDfIs02")!)
            }) {
                HStack(spacing: 4) {
                    Text("Buy Dev a Coffee")
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.orange)

            // Settings
            Button(showingSettings ? "Hide Settings" : "Settings") {
                showingSettings.toggle()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            if showingSettings {
                SettingsView(usageManager: usageManager)
            }
        }
        }
        .padding()
        .frame(width: 380, height: 460)
        .onAppear {
            if let savedCookie = UserDefaults.standard.string(forKey: "claude_session_cookie") {
                sessionCookieInput = String(savedCookie.prefix(20)) + "..."
            }
            usageManager.updatePercentages()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Legacy Claude-only usage display for backwards compatibility
struct LegacyClaudeUsageView: View {
    @ObservedObject var usageManager: MultiProviderUsageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Session Usage
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Session (5 hour)")
                        .font(.subheadline)
                    Spacer()
                    if let resetTime = usageManager.sessionResetsAt {
                        Text("Resets \(formatResetTime(resetTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                ProgressView(value: usageManager.sessionPercentage)
                    .tint(colorForPercentage(usageManager.sessionPercentage))

                Text("\(Int(usageManager.sessionPercentage * 100))% used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Weekly Usage
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Weekly (7 day)")
                        .font(.subheadline)
                    Spacer()
                    if let resetTime = usageManager.weeklyResetsAt {
                        Text("Resets \(formatResetTime(resetTime, includeDate: true))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                ProgressView(value: usageManager.weeklyPercentage)
                    .tint(colorForPercentage(usageManager.weeklyPercentage))

                Text("\(Int(usageManager.weeklyPercentage * 100))% used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Weekly Sonnet (Pro plan)
            if usageManager.hasWeeklySonnet {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Weekly Sonnet (7 day)")
                            .font(.subheadline)
                        Spacer()
                        if let resetTime = usageManager.weeklySonnetResetsAt {
                            Text("Resets \(formatResetTime(resetTime, includeDate: true))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    ProgressView(value: usageManager.weeklySonnetPercentage)
                        .tint(colorForPercentage(usageManager.weeklySonnetPercentage))

                    Text("\(Int(usageManager.weeklySonnetPercentage * 100))% used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func formatResetTime(_ date: Date, includeDate: Bool = false) -> String {
        let formatter = DateFormatter()
        if includeDate {
            formatter.dateFormat = "d MMM yyyy 'at' h:mm a"
            return "on \(formatter.string(from: date))"
        } else {
            formatter.timeStyle = .short
            return "at \(formatter.string(from: date))"
        }
    }

    private func colorForPercentage(_ percentage: Double) -> Color {
        if percentage < 0.7 {
            return .green
        } else if percentage < 0.9 {
            return .orange
        } else {
            return .red
        }
    }
}

/// Legacy cookie input view for backwards compatibility
struct LegacyCookieInputView: View {
    @Binding var sessionCookieInput: String
    @ObservedObject var usageManager: MultiProviderUsageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to get your Claude session cookie:")
                .font(.caption)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                Text("1. Go to Settings > Usage on claude.ai")
                Text("2. Press F12 (or Cmd+Option+I)")
                Text("3. Go to Network tab")
                Text("4. Refresh page, click 'usage' request")
                Text("5. Find 'Cookie' in Request Headers")
                Text("6. Copy full cookie value")
            }
            .font(.caption2)
            .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Paste full cookie string:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                TextEditor(text: $sessionCookieInput)
                    .font(.system(size: 11))
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.3), width: 1)

                HStack(spacing: 8) {
                    Button("Save Cookie & Fetch") {
                        if sessionCookieInput.isEmpty {
                            usageManager.errorMessage = "Cookie field is empty!"
                        } else {
                            usageManager.saveSessionCookie(sessionCookieInput)
                            usageManager.fetchUsage()
                            usageManager.errorMessage = "Cookie saved, fetching..."
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    if usageManager.hasFetchedData {
                        Button("Clear Cookie") {
                            sessionCookieInput = ""
                            usageManager.clearSessionCookie()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

// Type alias for backwards compatibility
typealias UsageView = MultiProviderUsageView
