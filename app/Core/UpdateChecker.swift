import Foundation
import AppKit

/// Checks GitHub for new releases and notifies users when updates are available
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var releaseURL: URL?
    @Published var dismissed: Bool = false

    private let githubRepo = "miguelbandeira/AIUsageBar"
    private let lastCheckKey = "last_update_check"
    private let checkIntervalSeconds: TimeInterval = 86400 // 24 hours

    private init() {}

    /// Check for updates, respecting the 24-hour rate limit unless forced
    func checkForUpdates(force: Bool = false) {
        guard force || shouldCheck() else {
            NSLog("⏭️ Skipping update check (checked recently)")
            return
        }

        NSLog("🔍 Checking for updates...")

        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            NSLog("❌ Invalid GitHub API URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("AIUsageBar/\(getCurrentVersion())", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                NSLog("❌ Update check failed: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                NSLog("❌ No data received from GitHub API")
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    NSLog("❌ Invalid JSON response")
                    return
                }

                // Check for API errors (404 = no releases)
                if let message = json["message"] as? String {
                    NSLog("⚠️ GitHub API: \(message)")
                    return
                }

                guard let tagName = json["tag_name"] as? String else {
                    NSLog("❌ No tag_name in response")
                    return
                }

                let htmlURL = json["html_url"] as? String

                // Strip 'v' prefix if present
                let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                let currentVersion = self.getCurrentVersion()

                NSLog("📊 Current: \(currentVersion), Latest: \(remoteVersion)")

                // Store last check time
                UserDefaults.standard.set(Date(), forKey: self.lastCheckKey)

                // Compare versions
                if self.compareVersions(currentVersion, remoteVersion) == .orderedAscending {
                    DispatchQueue.main.async {
                        self.latestVersion = remoteVersion
                        self.releaseURL = htmlURL.flatMap { URL(string: $0) }
                        self.updateAvailable = true
                        self.dismissed = false
                        NSLog("✅ Update available: \(remoteVersion)")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.updateAvailable = false
                        NSLog("✅ App is up to date")
                    }
                }
            } catch {
                NSLog("❌ Failed to parse GitHub response: \(error.localizedDescription)")
            }
        }.resume()
    }

    /// Returns true if enough time has passed since the last check
    func shouldCheck() -> Bool {
        guard let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date else {
            return true // Never checked before
        }

        let elapsed = Date().timeIntervalSince(lastCheck)
        return elapsed >= checkIntervalSeconds
    }

    /// Gets the current app version from Info.plist
    private func getCurrentVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Compares two semantic version strings
    /// Returns .orderedAscending if v1 < v2, .orderedDescending if v1 > v2, .orderedSame if equal
    private func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let components1 = v1.split(separator: ".").compactMap { Int($0) }
        let components2 = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(components1.count, components2.count)

        for i in 0..<maxLength {
            let c1 = i < components1.count ? components1[i] : 0
            let c2 = i < components2.count ? components2[i] : 0

            if c1 < c2 {
                return .orderedAscending
            } else if c1 > c2 {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    /// Opens the GitHub releases page in the default browser
    func openReleasesPage() {
        let url = releaseURL ?? URL(string: "https://github.com/\(githubRepo)/releases/latest")!
        NSWorkspace.shared.open(url)
    }

    /// Dismiss the update banner for this session
    func dismissUpdate() {
        dismissed = true
    }

    /// Simulate an update for testing purposes
    func simulateUpdate(version: String = "99.0.0") {
        DispatchQueue.main.async {
            self.latestVersion = version
            self.releaseURL = URL(string: "https://github.com/\(self.githubRepo)/releases/latest")
            self.updateAvailable = true
            self.dismissed = false
            NSLog("🧪 Simulated update available: \(version)")
        }
    }
}
