import SwiftUI
import AppKit

/// Main usage display view with multi-provider support
struct MultiProviderUsageView: View {
    @ObservedObject var usageManager: MultiProviderUsageManager
    @ObservedObject var updateChecker: UpdateChecker = UpdateChecker.shared
    @State private var showingSettings: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Update banner
                if updateChecker.updateAvailable && !updateChecker.dismissed {
                    UpdateBannerView(updateChecker: updateChecker)
                }

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
                VStack(alignment: .leading, spacing: 12) {
                    // Welcome header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome to AI Usage Bar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Track your AI usage across multiple providers in one place.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Quick start guide
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Get Started")
                            .font(.caption)
                            .fontWeight(.semibold)

                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("Click **Settings** below")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("Click on a provider to configure it")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("Follow the instructions to add your credentials")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Supported providers with visual cards
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Supported Providers")
                            .font(.caption)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            ForEach(Array(usageManager.providers.values), id: \.id) { provider in
                                HStack(spacing: 4) {
                                    Image(systemName: provider.displayConfig.iconName)
                                        .font(.system(size: 10))
                                    Text(provider.displayConfig.shortName)
                                        .font(.caption2)
                                }
                                .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: provider.displayConfig.primaryColor).opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }

                    // Recommendation
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Tip: Start with Claude if you have a Pro subscription")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(6)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }

            // Provider cards
            if usageManager.hasFetchedData {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(usageManager.providers.values), id: \.id) { provider in
                            if provider.isAuthenticated && AppSettings.shared.isProviderEnabled(provider.id) {
                                ProviderCardView(
                                    provider: provider,
                                    snapshot: usageManager.snapshot(for: provider.id)
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)

                Divider()

                // Last updated and refresh
                HStack {
                    Text("Last updated: \(formatTime(usageManager.lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Refresh") {
                        usageManager.fetchUsage()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            // Settings
            Button(showingSettings ? "Hide Settings" : "Settings") {
                showingSettings.toggle()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            if showingSettings {
                SettingsView(usageManager: usageManager)
            }

            // Support link
            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://donate.stripe.com/3cIcN5b5H7Q8ay8bIDfIs02")!)
            }) {
                HStack(spacing: 4) {
                    Text("Buy the original Dev a Coffee")
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.orange)

            // Check for Updates
            HStack(spacing: 8) {
                Button("Check for Updates") {
                    updateChecker.checkForUpdates(force: true)
                }
                .buttonStyle(.borderless)
                .font(.caption)

                if updateChecker.isUpToDate {
                    Text("Already up to date!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        }
        .padding()
        .frame(width: 380, height: 460)
        .onAppear {
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

/// Banner displayed when a new version is available
struct UpdateBannerView: View {
    @ObservedObject var updateChecker: UpdateChecker

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Update available")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("v\(updateChecker.latestVersion)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            Button("Download") {
                updateChecker.openReleasesPage()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.white)

            Button(action: {
                updateChecker.dismissUpdate()
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(8)
    }
}
