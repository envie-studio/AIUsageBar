import Foundation
import AppKit
import Combine

/// Manages multiple usage providers and orchestrates fetching/display
class MultiProviderUsageManager: ObservableObject {
    // MARK: - Published Properties

    @Published var providers: [String: UsageProvider] = [:]
    @Published var snapshots: [String: UsageSnapshot] = [:]
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date = Date()
    @Published var errorMessage: String?
    @Published var hasFetchedData: Bool = false

    // MARK: - Legacy Properties (for backwards compatibility)

    @Published var sessionUsage: Int = 0
    @Published var sessionLimit: Int = 100
    @Published var weeklyUsage: Int = 0
    @Published var weeklyLimit: Int = 100
    @Published var weeklySonnetUsage: Int = 0
    @Published var weeklySonnetLimit: Int = 100
    @Published var sessionResetsAt: Date?
    @Published var weeklyResetsAt: Date?
    @Published var weeklySonnetResetsAt: Date?
    @Published var hasWeeklySonnet: Bool = false
    @Published var sessionPercentage: Double = 0.0
    @Published var weeklyPercentage: Double = 0.0
    @Published var weeklySonnetPercentage: Double = 0.0
    @Published var notificationsEnabled: Bool = true
    @Published var openAtLogin: Bool = false
    @Published var isAccessibilityEnabled: Bool = false

    // MARK: - Private Properties

    private var statusItem: NSStatusItem?
    private weak var appDelegate: AppDelegate?
    private var cancellables = Set<AnyCancellable>()
    private let settings = AppSettings.shared
    private var refreshTimer: Timer?

    // MARK: - Initialization

    init(statusItem: NSStatusItem?, delegate: AppDelegate? = nil) {
        self.statusItem = statusItem
        self.appDelegate = delegate

        // Load settings
        notificationsEnabled = settings.notificationsEnabled
        openAtLogin = settings.openAtLogin
        checkAccessibilityStatus()

        // Register default providers
        registerProviders()

        // Migrate legacy credentials
        CredentialManager.shared.migrateLegacyClaudeCookie()

        // Subscribe to provider updates
        setupSubscriptions()
    }

    // MARK: - Provider Management

    private func registerProviders() {
        let claude = ClaudeWebProvider()
        let zhipu = ZhipuWebProvider()
        let codex = CodexProvider()
        let cursor = CursorProvider()
        let kimiK2 = KimiK2Provider()

        providers[claude.id] = claude
        providers[zhipu.id] = zhipu
        providers[codex.id] = codex
        providers[cursor.id] = cursor
        providers[kimiK2.id] = kimiK2

        // Register with global registry
        ProviderRegistry.shared.register(claude)
        ProviderRegistry.shared.register(zhipu)
        ProviderRegistry.shared.register(codex)
        ProviderRegistry.shared.register(cursor)
        ProviderRegistry.shared.register(kimiK2)
    }

    private func setupSubscriptions() {
        // Subscribe to each provider's usage updates
        for (_, provider) in providers {
            provider.usagePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] snapshot in
                    guard let self = self, let snapshot = snapshot else { return }
                    self.snapshots[snapshot.providerId] = snapshot
                    self.updateLegacyProperties(from: snapshot)
                    self.updateStatusBar()
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Public Methods

    func fetchUsage() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // Fetch from all enabled providers
        let enabledProviderIds = settings.enabledProviderIds

        Task {
            var hasAnyData = false
            var lastError: Error?

            for (id, provider) in providers {
                guard enabledProviderIds.contains(id), provider.isAuthenticated else {
                    continue
                }

                do {
                    _ = try await provider.fetchUsage()
                    hasAnyData = true
                } catch {
                    NSLog("MultiProviderUsageManager: Error fetching \(id): \(error)")
                    lastError = error
                }
            }

            await MainActor.run {
                self.isLoading = false
                self.lastUpdated = Date()

                if hasAnyData {
                    self.hasFetchedData = true
                    self.errorMessage = nil
                } else if let error = lastError {
                    self.errorMessage = error.localizedDescription
                } else if enabledProviderIds.isEmpty || !providers.values.contains(where: { $0.isAuthenticated }) {
                    self.errorMessage = "No providers configured"
                }
            }
        }
    }

    func provider(for id: String) -> UsageProvider? {
        return providers[id]
    }

    func snapshot(for id: String) -> UsageSnapshot? {
        return snapshots[id]
    }

    /// Get the primary provider's snapshot (for menu bar display)
    var primarySnapshot: UsageSnapshot? {
        // Use configured primary or fall back to first authenticated provider
        if let primaryId = settings.primaryProviderId,
           let snapshot = snapshots[primaryId] {
            return snapshot
        }

        // Fall back to Claude if authenticated and enabled
        if let claudeProvider = providers["claude"], 
           claudeProvider.isAuthenticated && 
           settings.isProviderEnabled(claudeProvider.id),
           let claudeSnapshot = snapshots["claude"] {
            return claudeSnapshot
        }

        // Return first enabled provider's snapshot
        return providers.values
            .filter { $0.isAuthenticated && settings.isProviderEnabled($0.id) }
            .compactMap { snapshots[$0.id] }
            .first
    }

    /// Get the highest usage percentage across all providers
    var maxUsagePercentage: Int {
        let maxPct = providers.values
            .filter { $0.isAuthenticated && settings.isProviderEnabled($0.id) }
            .compactMap { snapshots[$0.id]?.maxUsagePercentage }
            .max() ?? 0
        return Int(maxPct)
    }

    // MARK: - Legacy Methods (for backwards compatibility)

    func checkAccessibilityStatus() {
        isAccessibilityEnabled = AXIsProcessTrusted()
    }

    func updatePercentages() {
        sessionPercentage = Double(sessionUsage) / Double(sessionLimit)
        weeklyPercentage = Double(weeklyUsage) / Double(weeklyLimit)
        weeklySonnetPercentage = Double(weeklySonnetUsage) / Double(weeklySonnetLimit)
    }

    func saveSettings() {
        settings.notificationsEnabled = notificationsEnabled
        settings.openAtLogin = openAtLogin
    }

    func saveSessionCookie(_ cookie: String) {
        NSLog("MultiProviderUsageManager: Saving Claude cookie")
        guard let claude = providers["claude"] as? ClaudeWebProvider else { return }

        let credentials = ProviderCredentials(providerId: "claude", cookie: cookie)
        Task {
            try? await claude.configure(credentials: credentials)
        }
    }

    func clearSessionCookie() {
        NSLog("MultiProviderUsageManager: Clearing Claude cookie")
        guard let claude = providers["claude"] else { return }
        claude.clearCredentials()

        // Reset legacy properties
        sessionUsage = 0
        weeklyUsage = 0
        weeklySonnetUsage = 0
        sessionResetsAt = nil
        weeklyResetsAt = nil
        weeklySonnetResetsAt = nil
        hasFetchedData = false
        hasWeeklySonnet = false
        errorMessage = nil
        snapshots.removeValue(forKey: "claude")

        appDelegate?.updateStatusIcon(percentage: 0)
    }

    func sendTestNotification() {
        NSLog("MultiProviderUsageManager: Test notification")
        let notification = NSUserNotification()
        notification.title = "Usage Alert"
        notification.informativeText = "Test notification - You've reached 75% of your session limit"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    // MARK: - Private Methods

    private func updateLegacyProperties(from snapshot: UsageSnapshot) {
        // Only update legacy properties from Claude provider for backwards compatibility
        guard snapshot.providerId == "claude" else { return }

        for quota in snapshot.quotas {
            switch quota.id {
            case "session":
                sessionUsage = Int(quota.computedPercentage)
                sessionResetsAt = quota.resetDate

            case "weekly":
                weeklyUsage = Int(quota.computedPercentage)
                weeklyResetsAt = quota.resetDate

            case "weekly_sonnet":
                weeklySonnetUsage = Int(quota.computedPercentage)
                weeklySonnetResetsAt = quota.resetDate
                hasWeeklySonnet = true

            default:
                break
            }
        }

        updatePercentages()
    }

    private func updateStatusBar() {
        // Collect all authenticated providers with their percentages
        var providerInfos: [(shortName: String, percentage: Int)] = []

        for provider in providers.values {
            if provider.isAuthenticated && 
               settings.isProviderEnabled(provider.id), 
               let snapshot = snapshots[provider.id] {
                let percentage = Int(snapshot.maxUsagePercentage)
                providerInfos.append((provider.displayConfig.shortName, percentage))
            }
        }

        // Sort by name for consistent ordering
        providerInfos.sort { $0.shortName < $1.shortName }

        if providerInfos.isEmpty {
            appDelegate?.updateStatusIcon(percentage: 0)
        } else {
            appDelegate?.updateStatusIconMultiple(providers: providerInfos)
        }

        // Use primary provider or highest usage for notifications
        let percentage: Int
        if let primary = primarySnapshot {
            percentage = Int(primary.maxUsagePercentage)
        } else {
            percentage = maxUsagePercentage
        }
        checkNotificationThresholds(percentage: percentage)
    }

    private func checkNotificationThresholds(percentage: Int) {
        guard settings.notificationsEnabled else { return }

        let providerId = primarySnapshot?.providerId ?? "default"
        let lastThreshold = settings.getLastNotifiedThreshold(for: providerId)
        let thresholds = [25, 50, 75, 90]

        for threshold in thresholds {
            if percentage >= threshold && lastThreshold < threshold {
                sendNotification(percentage: percentage, threshold: threshold)
                settings.setLastNotifiedThreshold(threshold, for: providerId)
            }
        }

        // Reset if usage drops
        if percentage < lastThreshold {
            let newThreshold = thresholds.filter { $0 <= percentage }.last ?? 0
            settings.setLastNotifiedThreshold(newThreshold, for: providerId)
        }
    }

    private func sendNotification(percentage: Int, threshold: Int) {
        let providerName = primarySnapshot.map { providers[$0.providerId]?.name } ?? "AI"

        let notification = NSUserNotification()
        notification.title = "\(providerName ?? "Usage") Alert"
        notification.informativeText = "You've reached \(percentage)% of your session limit"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)

        NSLog("MultiProviderUsageManager: Sent notification for \(threshold)% threshold")
    }
}

// MARK: - Type Alias for Backwards Compatibility
typealias UsageManager = MultiProviderUsageManager
