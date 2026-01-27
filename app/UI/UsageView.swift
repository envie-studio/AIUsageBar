import SwiftUI
import AppKit

/// Main usage display view with tab-based navigation
struct MultiProviderUsageView: View {
    @ObservedObject var usageManager: MultiProviderUsageManager
    @ObservedObject var updateChecker: UpdateChecker = UpdateChecker.shared
    @ObservedObject var tabState = TabState.shared
    @State private var showingSettings: Bool = false
    @State private var showingOnboarding: Bool = false
    @State private var popoverHeight: CGFloat = 500
    @State private var popoverWidth: CGFloat = 380

    var body: some View {
        VStack(spacing: 0) {
            if showingSettings {
                headerWithSettingsTitle
            } else {
                TabBar(
                    tabState: tabState,
                    providers: Array(usageManager.providers.values).filter { AppSettings.shared.isProviderEnabled($0.id) },
                    snapshots: usageManager.snapshots
                )
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showingSettings {
                        VStack(alignment: .leading, spacing: 16) {
                            settingsView
                        }
                    } else if showingOnboarding {
                        VStack(alignment: .leading, spacing: 16) {
                            onboardingView
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            tabContent
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: popoverHeight - 88)
            .animation(.easeInOut(duration: 0.15), value: tabState.selectedTab)
            .animation(.easeInOut(duration: 0.15), value: showingSettings)
            .animation(.easeInOut(duration: 0.15), value: showingOnboarding)

            if !showingSettings {
                Divider()

                footer
            }
        }
        .frame(width: popoverWidth, height: popoverHeight)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            updatePopoverSize()
            showingOnboarding = !hasConfiguredProviders
        }
        .onChange(of: tabState.selectedTab) { _ in
            updatePopoverSize()
        }
        .onChange(of: showingSettings) { _ in
            updatePopoverSize()
        }
    }

    private var headerWithSettingsTitle: some View {
        HStack(spacing: 12) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Button("Back to Overview") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showingSettings = false
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tabState.selectedTab {
        case .overview:
            OverviewTabView(usageManager: usageManager) { providerId in
                tabState.selectProvider(providerId)
            }
        case .provider(let providerId):
            if let provider = usageManager.providers[providerId] {
                ProviderDetailTabView(
                    provider: provider,
                    snapshot: usageManager.snapshots[providerId],
                    onConfigure: { showingSettings = true }
                )
            }
        }
    }

    private var onboardingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to AI Usage Bar")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Track your AI usage across multiple providers in one place.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Get Started")
                    .font(.caption)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 6) {
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
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Supported Providers")
                    .font(.caption)
                    .fontWeight(.semibold)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(Array(usageManager.providers.values), id: \.id) { provider in
                        HStack(spacing: 6) {
                            Image(systemName: provider.displayConfig.iconName)
                                .font(.system(size: 11))
                            Text(provider.displayConfig.shortName)
                                .font(.caption2)
                        }
                        .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: provider.displayConfig.primaryColor).opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }

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
    }

    private var settingsView: some View {
        SettingsView(usageManager: usageManager)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                if usageManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Text("Updated: \(formatTime(usageManager.lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(showingSettings ? "Done" : "Settings") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showingSettings.toggle()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Button("Refresh") {
                    usageManager.fetchUsage()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(usageManager.isLoading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var hasConfiguredProviders: Bool {
        return usageManager.providers.values.contains { $0.isAuthenticated }
    }

    private func updatePopoverSize() {
        var width: CGFloat = 380

        let enabledCount = usageManager.providers.values
            .filter { $0.isAuthenticated && AppSettings.shared.isProviderEnabled($0.id) }
            .count

        if enabledCount >= 4 {
            width = 420
        } else if enabledCount >= 6 {
            width = 460
        }

        var height: CGFloat = 300

        if showingSettings {
            height = 500
        } else if showingOnboarding {
            height = 480
        } else if case .overview = tabState.selectedTab {
            height = min(500, CGFloat(200 + enabledCount * 80))
        } else {
            height = 400
        }

        height = min(max(height, 300), 600)

        withAnimation(.easeInOut(duration: 0.2)) {
            popoverWidth = width
            popoverHeight = height
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
