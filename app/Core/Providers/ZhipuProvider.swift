import Foundation
import Combine

/// Provider for Z.ai/Zhipu GLM Coding Plan usage tracking
/// Note: This requires reverse engineering the Z.ai dashboard
/// or examining the glm-plan-usage plugin source
class ZhipuWebProvider: UsageProvider {
    // MARK: - UsageProvider Protocol

    let id = "zhipu"
    let name = "Zhipu GLM"
    let authMethod: AuthMethod = .cookie

    @Published private(set) var authState: AuthState = .notConfigured
    @Published private(set) var latestUsage: UsageSnapshot?

    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> {
        $latestUsage.eraseToAnyPublisher()
    }

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    let displayConfig = ProviderDisplayConfig.zhipu

    var credentialInstructions: [String] {
        [
            "1. Go to z.ai or open.bigmodel.cn dashboard",
            "2. Sign in with your account",
            "3. Press F12 (or Cmd+Option+I)",
            "4. Go to Network tab",
            "5. Navigate to usage/billing section",
            "6. Look for API requests",
            "7. Find 'Cookie' in Request Headers",
            "8. Copy full cookie value"
        ]
    }

    // MARK: - Private Properties

    private var sessionCookie: String = ""
    private let credentialManager = CredentialManager.shared

    // Known endpoints (need verification):
    // - api.z.ai/api/anthropic (Claude Code via Z.ai)
    // - api.z.ai/api/coding/paas/v4
    // - open.bigmodel.cn/api/* (main BigModel API)

    // Quota information:
    // - Lite: ~120 prompts/5hr
    // - Pro: ~600 prompts/5hr
    // - Max: ~2400 prompts/5hr

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

        authState = .validating

        do {
            // Try to validate by fetching usage
            _ = try await fetchUsage()
            authState = .authenticated
            NSLog("ZhipuWebProvider: Configured successfully")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard !sessionCookie.isEmpty else {
            throw ProviderError.notConfigured
        }

        // TODO: Discover actual endpoint from Z.ai dashboard
        // Try multiple potential endpoints

        var quotas: [QuotaMetric] = []

        // Try Z.ai API
        if let zaiQuotas = try? await fetchZaiUsage() {
            quotas.append(contentsOf: zaiQuotas)
        }

        // Try BigModel API
        if quotas.isEmpty, let bigmodelQuotas = try? await fetchBigModelUsage() {
            quotas.append(contentsOf: bigmodelQuotas)
        }

        // If no quotas found, return placeholder
        if quotas.isEmpty {
            NSLog("ZhipuWebProvider: Could not fetch usage, returning placeholder")
            quotas = [
                QuotaMetric(
                    id: "session",
                    name: "Session (5 hour)",
                    percentage: nil,
                    used: nil,
                    limit: nil,
                    unit: "prompts",
                    resetDate: nil
                )
            ]
        }

        let snapshot = UsageSnapshot(
            providerId: id,
            timestamp: Date(),
            quotas: quotas
        )

        latestUsage = snapshot
        authState = .authenticated

        return snapshot
    }

    func clearCredentials() {
        sessionCookie = ""
        latestUsage = nil
        authState = .notConfigured

        try? credentialManager.delete(for: id)
        NSLog("ZhipuWebProvider: Credentials cleared")
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
        if let credentials = credentialManager.load(for: id) {
            sessionCookie = credentials.cookie ?? ""

            if !sessionCookie.isEmpty {
                authState = .authenticated
                NSLog("ZhipuWebProvider: Loaded credentials from Keychain")
            }
        }
    }

    private func fetchZaiUsage() async throws -> [QuotaMetric] {
        // Try Z.ai coding plan usage endpoint
        // TODO: Discover actual endpoint

        // Potential endpoints:
        // - api.z.ai/api/user/usage
        // - api.z.ai/api/coding/usage
        // - api.z.ai/api/billing/usage

        guard let url = URL(string: "https://api.z.ai/api/user/usage") else {
            throw ProviderError.unknown("Invalid Z.ai URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        NSLog("ZhipuWebProvider: Trying Z.ai endpoint...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            NSLog("ZhipuWebProvider: Z.ai endpoint returned \(httpResponse.statusCode)")
            throw ProviderError.serverError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid JSON")
        }

        NSLog("ZhipuWebProvider: Z.ai response: \(json)")

        // TODO: Parse actual response structure
        // Expected similar to Claude: utilization percentage + resets_at

        return parseUsageResponse(json)
    }

    private func fetchBigModelUsage() async throws -> [QuotaMetric] {
        // Try BigModel (open.bigmodel.cn) usage endpoint

        guard let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/usage") else {
            throw ProviderError.unknown("Invalid BigModel URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        NSLog("ZhipuWebProvider: Trying BigModel endpoint...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            NSLog("ZhipuWebProvider: BigModel endpoint returned \(httpResponse.statusCode)")
            throw ProviderError.serverError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid JSON")
        }

        NSLog("ZhipuWebProvider: BigModel response: \(json)")

        return parseUsageResponse(json)
    }

    private func parseUsageResponse(_ json: [String: Any]) -> [QuotaMetric] {
        // Attempt to parse a Claude-like response structure
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var quotas: [QuotaMetric] = []

        // Try to find session/5-hour quota
        if let fiveHour = json["five_hour"] as? [String: Any] ?? json["session"] as? [String: Any] {
            let utilization = fiveHour["utilization"] as? Double ?? fiveHour["percentage"] as? Double ?? 0
            var resetDate: Date?

            if let resetsAtString = fiveHour["resets_at"] as? String ?? fiveHour["reset_time"] as? String {
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

        // Try to find daily/weekly quota
        if let daily = json["daily"] as? [String: Any] ?? json["seven_day"] as? [String: Any] {
            let utilization = daily["utilization"] as? Double ?? daily["percentage"] as? Double ?? 0
            var resetDate: Date?

            if let resetsAtString = daily["resets_at"] as? String ?? daily["reset_time"] as? String {
                resetDate = iso8601Formatter.date(from: resetsAtString)
            }

            quotas.append(QuotaMetric(
                id: "daily",
                name: "Daily/Weekly",
                percentage: utilization,
                unit: "%",
                resetDate: resetDate
            ))
        }

        // Try generic usage format
        if quotas.isEmpty {
            if let used = json["used"] as? Double ?? json["current"] as? Double,
               let limit = json["limit"] as? Double ?? json["total"] as? Double {
                let percentage = limit > 0 ? (used / limit) * 100 : 0

                quotas.append(QuotaMetric(
                    id: "usage",
                    name: "Usage",
                    percentage: percentage,
                    used: used,
                    limit: limit,
                    unit: "prompts"
                ))
            }
        }

        return quotas
    }
}
