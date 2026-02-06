import Foundation
import Combine

// MARK: - Cursor API Response Models

private struct CursorUsageSummary: Codable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let membershipType: String?
    let limitType: String?
    let isUnlimited: Bool?
    let individualUsage: CursorIndividualUsage?
    let teamUsage: CursorTeamUsage?
}

private struct CursorIndividualUsage: Codable {
    let plan: CursorPlanUsage?
    let onDemand: CursorOnDemandUsage?
}

private struct CursorPlanUsage: Codable {
    let enabled: Bool?
    let used: Int?          // cents
    let limit: Int?         // cents
    let remaining: Int?     // cents
    let totalPercentUsed: Double?
}

private struct CursorOnDemandUsage: Codable {
    let enabled: Bool?
    let used: Int?          // cents
    let limit: Int?         // cents
    let remaining: Int?     // cents
}

private struct CursorTeamUsage: Codable {
    let onDemand: CursorOnDemandUsage?
}

private struct CursorUserInfo: Codable {
    let email: String?
    let name: String?
    let sub: String?

    enum CodingKeys: String, CodingKey {
        case email, name, sub
    }
}

/// Provider for Cursor AI (cursor.com) usage tracking
class CursorProvider: UsageProvider {
    // MARK: - UsageProvider Protocol

    let id = "cursor"
    let name = "Cursor"
    let authMethod: AuthMethod = .cookie

    @Published private(set) var authState: AuthState = .notConfigured
    @Published private(set) var latestUsage: UsageSnapshot?

    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> {
        $latestUsage.eraseToAnyPublisher()
    }

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    let displayConfig = ProviderDisplayConfig.cursor

    var credentialInstructions: [String] {
        [
            "Open cursor.com in your browser and sign in",
            "Press F12 (or Cmd+Option+I) to open DevTools",
            "Go to Application tab, then Cookies",
            "Find the cookie named WorkosCursorSessionToken",
            "Copy the full cookie value",
            "If not found, try __Secure-next-auth.session-token"
        ]
    }

    // MARK: - Private Properties

    private var sessionCookie: String = ""
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

        // Save to keychain
        try credentialManager.save(credentials)

        // Validate by fetching user info
        authState = .validating

        do {
            _ = try await fetchUserInfo()
            authState = .authenticated
            NSLog("CursorProvider: Configured successfully")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard !sessionCookie.isEmpty else {
            throw ProviderError.notConfigured
        }

        guard let url = URL(string: "https://cursor.com/api/usage-summary") else {
            throw ProviderError.unknown("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(buildCookieHeader(from: sessionCookie), forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.setValue("https://cursor.com/settings", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        NSLog("CursorProvider: Fetching usage summary")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        NSLog("CursorProvider: Status \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            authState = .failed("Session expired")
            throw ProviderError.invalidCredentials
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderError.serverError(httpResponse.statusCode)
        }

        let snapshot = try parseUsageSummary(data)
        latestUsage = snapshot
        authState = .authenticated

        return snapshot
    }

    func clearCredentials() {
        sessionCookie = ""
        latestUsage = nil
        authState = .notConfigured

        try? credentialManager.delete(for: id)
        NSLog("CursorProvider: Credentials cleared")
    }

    func validateCredentials() async -> Bool {
        guard !sessionCookie.isEmpty else { return false }

        do {
            _ = try await fetchUserInfo()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func loadCredentials() {
        if let credentials = credentialManager.load(for: id) {
            sessionCookie = credentials.cookie ?? ""

            if !sessionCookie.isEmpty {
                authState = .authenticated
                NSLog("CursorProvider: Loaded credentials from Keychain")
            }
        }
    }

    /// Validate credentials by fetching user info from /api/auth/me
    private func fetchUserInfo() async throws -> String {
        guard let url = URL(string: "https://cursor.com/api/auth/me") else {
            throw ProviderError.unknown("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(buildCookieHeader(from: sessionCookie), forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw ProviderError.invalidCredentials
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        if let userInfo = try? decoder.decode(CursorUserInfo.self, from: data),
           let email = userInfo.email {
            NSLog("CursorProvider: Authenticated as \(email)")
            return email
        }

        return "authenticated"
    }

    /// Build the Cookie header from user input.
    /// Handles raw token values, single name=value pairs, or full cookie strings.
    private func buildCookieHeader(from rawInput: String) -> String {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

        let knownCookieNames = [
            "WorkosCursorSessionToken",
            "__Secure-next-auth.session-token",
            "next-auth.session-token"
        ]

        for name in knownCookieNames {
            if trimmed.contains("\(name)=") {
                return trimmed
            }
        }

        // Raw value without cookie name - wrap with the primary cookie name
        return "WorkosCursorSessionToken=\(trimmed)"
    }

    private func parseUsageSummary(_ data: Data) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        let summary: CursorUsageSummary

        do {
            summary = try decoder.decode(CursorUsageSummary.self, from: data)
        } catch {
            NSLog("CursorProvider: Failed to decode response: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                NSLog("CursorProvider: Raw response: \(raw)")
            }
            throw ProviderError.parseError("Failed to decode usage summary: \(error.localizedDescription)")
        }

        var quotas: [QuotaMetric] = []
        var totalCost: Decimal? = nil

        // Parse billing cycle end date for reset indicator
        let billingEndDate = parseBillingEndDate(summary.billingCycleEnd)

        // Parse plan usage
        if let plan = summary.individualUsage?.plan {
            let planUsedCents = Double(plan.used ?? 0)
            let planLimitCents = Double(plan.limit ?? 0)

            // Calculate percentage from raw values (cents), falling back to API-provided percentage
            let planPercent: Double
            if planLimitCents > 0 {
                planPercent = (planUsedCents / planLimitCents) * 100.0
            } else if let apiPercent = plan.totalPercentUsed {
                // API may return 0-1 or 0-100 range
                planPercent = apiPercent <= 1.0 ? apiPercent * 100.0 : apiPercent
            } else {
                planPercent = 0
            }

            let planUsedUSD = planUsedCents / 100.0
            let planLimitUSD = planLimitCents / 100.0

            quotas.append(QuotaMetric(
                id: "plan",
                name: "Plan Usage",
                percentage: planPercent,
                used: planLimitUSD > 0 ? planUsedUSD : nil,
                limit: planLimitUSD > 0 ? planLimitUSD : nil,
                unit: planLimitUSD > 0 ? "USD" : "%",
                resetDate: billingEndDate
            ))
        }

        // Parse on-demand usage
        if let onDemand = summary.individualUsage?.onDemand, onDemand.enabled == true {
            let onDemandUsedCents = Double(onDemand.used ?? 0)
            let onDemandLimitCents = onDemand.limit.map { Double($0) }
            let onDemandUsedUSD = onDemandUsedCents / 100.0

            var onDemandPercent: Double? = nil
            var onDemandLimitUSD: Double? = nil

            if let limitCents = onDemandLimitCents, limitCents > 0 {
                onDemandPercent = (onDemandUsedCents / limitCents) * 100.0
                onDemandLimitUSD = limitCents / 100.0
            }

            totalCost = Decimal(onDemandUsedUSD)

            quotas.append(QuotaMetric(
                id: "on_demand",
                name: "On-Demand",
                percentage: onDemandPercent,
                used: onDemandUsedUSD,
                limit: onDemandLimitUSD,
                unit: "USD",
                resetDate: billingEndDate
            ))
        }

        let snapshot = UsageSnapshot(
            providerId: id,
            timestamp: Date(),
            quotas: quotas,
            totalCost: totalCost
        )

        NSLog("CursorProvider: Parsed \(quotas.count) quotas")
        return snapshot
    }

    private func parseBillingEndDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return date }

        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd"
        return simple.date(from: dateString)
    }
}
