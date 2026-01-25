import Foundation
import Combine

/// Provider for Claude.ai web usage tracking
class ClaudeWebProvider: UsageProvider {
    // MARK: - UsageProvider Protocol

    let id = "claude"
    let name = "Claude"
    let authMethod: AuthMethod = .cookie

    @Published private(set) var authState: AuthState = .notConfigured
    @Published private(set) var latestUsage: UsageSnapshot?

    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> {
        $latestUsage.eraseToAnyPublisher()
    }

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    let displayConfig = ProviderDisplayConfig.claude

    var credentialInstructions: [String] {
        [
            "1. Go to Settings > Usage on claude.ai",
            "2. Press F12 (or Cmd+Option+I)",
            "3. Go to Network tab",
            "4. Refresh page, click 'usage' request",
            "5. Find 'Cookie' in Request Headers",
            "6. Copy full cookie value (starts with anthropic-device-id=...)"
        ]
    }

    // MARK: - Private Properties

    private var sessionCookie: String = ""
    private var organizationId: String?
    private let credentialManager = CredentialManager.shared

    // MARK: - Initialization

    init() {
        loadCredentials()
    }

    // MARK: - Public Methods

    func configure(credentials: ProviderCredentials) async throws {
        guard let cookie = credentials.cookie, !cookie.isEmpty else {
            throw ProviderError.invalidCredentials
        }

        sessionCookie = cookie
        organizationId = credentials.organizationId

        // Save to keychain
        try credentialManager.save(credentials)

        // Validate by fetching org ID
        authState = .validating

        do {
            if organizationId == nil {
                organizationId = try await fetchOrganizationId()
            }
            authState = .authenticated
            NSLog("ClaudeWebProvider: Configured successfully")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard !sessionCookie.isEmpty else {
            throw ProviderError.notConfigured
        }

        // Get org ID if we don't have it
        if organizationId == nil {
            organizationId = try await fetchOrganizationId()
        }

        guard let orgId = organizationId else {
            throw ProviderError.invalidCredentials
        }

        let urlString = "https://claude.ai/api/organizations/\(orgId)/usage"

        guard let url = URL(string: urlString) else {
            throw ProviderError.unknown("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        NSLog("ClaudeWebProvider: Fetching from \(urlString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        NSLog("ClaudeWebProvider: Status \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            authState = .failed("Session expired")
            throw ProviderError.invalidCredentials
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderError.serverError(httpResponse.statusCode)
        }

        let snapshot = try parseUsageData(data)
        latestUsage = snapshot
        authState = .authenticated

        return snapshot
    }

    func clearCredentials() {
        sessionCookie = ""
        organizationId = nil
        latestUsage = nil
        authState = .notConfigured

        try? credentialManager.delete(for: id)
        NSLog("ClaudeWebProvider: Credentials cleared")
    }

    func validateCredentials() async -> Bool {
        guard !sessionCookie.isEmpty else { return false }

        do {
            _ = try await fetchUsage()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func loadCredentials() {
        // First try Keychain
        if let credentials = credentialManager.load(for: id) {
            sessionCookie = credentials.cookie ?? ""
            organizationId = credentials.organizationId

            if !sessionCookie.isEmpty {
                authState = .authenticated
                NSLog("ClaudeWebProvider: Loaded credentials from Keychain")
            }
            return
        }

        // Fallback to legacy UserDefaults (for migration)
        if let legacyCookie = UserDefaults.standard.string(forKey: "claude_session_cookie"),
           !legacyCookie.isEmpty {
            sessionCookie = legacyCookie

            // Migrate to Keychain
            let credentials = ProviderCredentials(providerId: id, cookie: legacyCookie)
            try? credentialManager.save(credentials)

            // Remove from UserDefaults
            UserDefaults.standard.removeObject(forKey: "claude_session_cookie")
            UserDefaults.standard.synchronize()

            authState = .authenticated
            NSLog("ClaudeWebProvider: Migrated legacy cookie to Keychain")
        }
    }

    private func fetchOrganizationId() async throws -> String {
        // First try to extract from cookie
        let cookieParts = sessionCookie.components(separatedBy: ";")
        for part in cookieParts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("lastActiveOrg=") {
                let orgId = trimmed.replacingOccurrences(of: "lastActiveOrg=", with: "")
                NSLog("ClaudeWebProvider: Found org ID in cookie: \(orgId)")
                return orgId
            }
        }

        // Fetch from bootstrap endpoint
        guard let url = URL(string: "https://claude.ai/api/bootstrap") else {
            throw ProviderError.unknown("Invalid bootstrap URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("sessionKey=\(sessionCookie)", forHTTPHeaderField: "Cookie")

        NSLog("ClaudeWebProvider: Fetching bootstrap for org ID...")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = json["account"] as? [String: Any],
              let lastActiveOrgId = account["lastActiveOrgId"] as? String else {
            throw ProviderError.parseError("Could not extract org ID from bootstrap")
        }

        NSLog("ClaudeWebProvider: Got org ID from bootstrap: \(lastActiveOrgId)")
        return lastActiveOrgId
    }

    private func parseUsageData(_ data: Data) throws -> UsageSnapshot {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid JSON")
        }

        NSLog("ClaudeWebProvider: Parsing usage data...")

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var quotas: [QuotaMetric] = []

        // Parse 5-hour session quota
        if let fiveHour = json["five_hour"] as? [String: Any] {
            let utilization = fiveHour["utilization"] as? Double ?? 0
            var resetDate: Date?

            if let resetsAtString = fiveHour["resets_at"] as? String {
                resetDate = iso8601Formatter.date(from: resetsAtString)
            }

            quotas.append(QuotaMetric(
                id: "session",
                name: "Session (5 hour)",
                percentage: utilization,
                unit: "%",
                resetDate: resetDate
            ))
        }

        // Parse 7-day weekly quota
        if let sevenDay = json["seven_day"] as? [String: Any] {
            let utilization = sevenDay["utilization"] as? Double ?? 0
            var resetDate: Date?

            if let resetsAtString = sevenDay["resets_at"] as? String {
                resetDate = iso8601Formatter.date(from: resetsAtString)
            }

            quotas.append(QuotaMetric(
                id: "weekly",
                name: "Weekly (7 day)",
                percentage: utilization,
                unit: "%",
                resetDate: resetDate
            ))
        }

        // Parse 7-day Sonnet quota (Pro plan)
        if let sevenDaySonnet = json["seven_day_sonnet"] as? [String: Any] {
            let utilization = sevenDaySonnet["utilization"] as? Double ?? 0
            var resetDate: Date?

            if let resetsAtString = sevenDaySonnet["resets_at"] as? String {
                resetDate = iso8601Formatter.date(from: resetsAtString)
            }

            quotas.append(QuotaMetric(
                id: "weekly_sonnet",
                name: "Weekly Sonnet (7 day)",
                percentage: utilization,
                unit: "%",
                resetDate: resetDate
            ))
        }

        let snapshot = UsageSnapshot(
            providerId: id,
            timestamp: Date(),
            quotas: quotas
        )

        NSLog("ClaudeWebProvider: Parsed \(quotas.count) quotas")

        return snapshot
    }
}
