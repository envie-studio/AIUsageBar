import Foundation

/// App-wide settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var notificationsEnabled: Bool {
        didSet { save() }
    }
    @Published var openAtLogin: Bool {
        didSet { save() }
    }
    @Published var primaryProviderId: String? {
        didSet { save() }
    }
    @Published var enabledProviderIds: Set<String> {
        didSet { save() }
    }
    @Published var lastNotifiedThresholds: [String: Int] {
        didSet { save() }
    }
    @Published var refreshIntervalSeconds: Int {
        didSet { save() }
    }
    @Published var showPercentageInMenuBar: Bool {
        didSet { save() }
    }
    @Published var lastOpenedTab: String {
        didSet { save() }
    }
    @Published var preferredQuotaIds: [String: String] {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard

    private init() {
        // Load settings from UserDefaults
        self.notificationsEnabled = defaults.bool(forKey: "notifications_enabled")
        self.openAtLogin = defaults.bool(forKey: "open_at_login")
        self.primaryProviderId = defaults.string(forKey: "primary_provider_id")
        self.refreshIntervalSeconds = defaults.integer(forKey: "refresh_interval_seconds")
        self.showPercentageInMenuBar = defaults.bool(forKey: "show_percentage_in_menu_bar")
        self.lastOpenedTab = defaults.string(forKey: "last_opened_tab") ?? "overview"

        // Load preferred quota IDs (default to session for Claude)
        self.preferredQuotaIds = (defaults.dictionary(forKey: "preferred_quota_ids") as? [String: String]) ?? ["claude": "session"]

        // Load enabled providers
        self.enabledProviderIds = defaults.stringArray(forKey: "enabled_provider_ids").map { Set($0) } ?? ["claude"]

        // Load notification thresholds
        self.lastNotifiedThresholds = (defaults.dictionary(forKey: "last_notified_thresholds") as? [String: Int]) ?? [:]

        // Set defaults if not configured
        if !defaults.bool(forKey: "has_set_notifications") {
            self.notificationsEnabled = true
            defaults.set(true, forKey: "has_set_notifications")
        }

        if refreshIntervalSeconds == 0 {
            self.refreshIntervalSeconds = 300  // Default 5 minutes
        }

        if !defaults.bool(forKey: "has_set_menu_bar_percentage") {
            self.showPercentageInMenuBar = true
            defaults.set(true, forKey: "has_set_menu_bar_percentage")
        }
    }

    private func save() {
        defaults.set(notificationsEnabled, forKey: "notifications_enabled")
        defaults.set(openAtLogin, forKey: "open_at_login")
        defaults.set(primaryProviderId, forKey: "primary_provider_id")
        defaults.set(Array(enabledProviderIds), forKey: "enabled_provider_ids")
        defaults.set(lastNotifiedThresholds, forKey: "last_notified_thresholds")
        defaults.set(refreshIntervalSeconds, forKey: "refresh_interval_seconds")
        defaults.set(showPercentageInMenuBar, forKey: "show_percentage_in_menu_bar")
        defaults.set(lastOpenedTab, forKey: "last_opened_tab")
        defaults.set(preferredQuotaIds, forKey: "preferred_quota_ids")
        defaults.synchronize()
    }

    func getLastNotifiedThreshold(for providerId: String) -> Int {
        return lastNotifiedThresholds[providerId] ?? 0
    }

    func setLastNotifiedThreshold(_ threshold: Int, for providerId: String) {
        lastNotifiedThresholds[providerId] = threshold
    }

    func isProviderEnabled(_ providerId: String) -> Bool {
        return enabledProviderIds.contains(providerId)
    }

    func setProviderEnabled(_ providerId: String, enabled: Bool) {
        if enabled {
            enabledProviderIds.insert(providerId)
        } else {
            enabledProviderIds.remove(providerId)
        }
    }

    func getPreferredQuotaId(for providerId: String) -> String? {
        return preferredQuotaIds[providerId]
    }

    func setPreferredQuotaId(_ quotaId: String?, for providerId: String) {
        preferredQuotaIds[providerId] = quotaId
    }
}
