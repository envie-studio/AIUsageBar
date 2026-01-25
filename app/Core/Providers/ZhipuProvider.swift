import Foundation
import Combine

/// Provider for Z.ai (GLM Coding) usage tracking
/// Uses Bearer token authentication from the Z.ai dashboard
class ZaiProvider: UsageProvider {
    // MARK: - UsageProvider Protocol

    let id = "zhipu"  // Keep ID for backwards compatibility with stored credentials
    let name = "Z.ai"
    let authMethod: AuthMethod = .bearerToken

    @Published private(set) var authState: AuthState = .notConfigured
    @Published private(set) var latestUsage: UsageSnapshot?

    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> {
        $latestUsage.eraseToAnyPublisher()
    }

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    let displayConfig = ProviderDisplayConfig.zai

    var credentialInstructions: [String] {
        [
            "1. Go to z.ai and sign in",
            "2. Open DevTools (Cmd+Option+I)",
            "3. Go to Network tab, then reload the page",
            "4. Click any request, go to Headers tab",
            "5. Find \"authorization: Bearer eyJ...\"",
            "6. Copy only the token (after \"Bearer \")"
        ]
    }

    // MARK: - Private Properties

    private var bearerToken: String = ""
    private let credentialManager = CredentialManager.shared

    // API endpoint for quota usage
    private let usageEndpoint = "https://api.z.ai/api/monitor/usage/quota/limit"

    // MARK: - Initialization

    init() {
        loadCredentials()
    }

    // MARK: - Public Methods

    func configure(credentials: ProviderCredentials) async throws {
        guard let token = credentials.bearerToken, !token.isEmpty else {
            throw ProviderError.invalidCredentials
        }

        bearerToken = token

        // Save to keychain
        try credentialManager.save(credentials)

        authState = .validating

        do {
            // Validate by fetching usage
            _ = try await fetchUsage()
            authState = .authenticated
            NSLog("ZaiProvider: Configured successfully")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard !bearerToken.isEmpty else {
            throw ProviderError.notConfigured
        }

        guard let url = URL(string: usageEndpoint) else {
            throw ProviderError.unknown("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        NSLog("ZaiProvider: Fetching usage from \(usageEndpoint)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        NSLog("ZaiProvider: Status \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            authState = .failed("Token expired or invalid")
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
        bearerToken = ""
        latestUsage = nil
        authState = .notConfigured

        try? credentialManager.delete(for: id)
        NSLog("ZaiProvider: Credentials cleared")
    }

    func validateCredentials() async -> Bool {
        guard !bearerToken.isEmpty else { return false }

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
            bearerToken = credentials.bearerToken ?? ""

            if !bearerToken.isEmpty {
                authState = .authenticated
                NSLog("ZaiProvider: Loaded credentials from Keychain")
            }
        }
    }

    private func parseUsageData(_ data: Data) throws -> UsageSnapshot {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid JSON")
        }

        NSLog("ZaiProvider: Parsing usage data...")

        // Check for error response
        if let code = json["code"] as? Int, code != 200 {
            let message = json["message"] as? String ?? "Unknown error"
            throw ProviderError.parseError("API error \(code): \(message)")
        }

        guard let dataDict = json["data"] as? [String: Any],
              let limits = dataDict["limits"] as? [[String: Any]] else {
            throw ProviderError.parseError("Missing 'data.limits' in response")
        }

        var quotas: [QuotaMetric] = []

        for limit in limits {
            guard let type = limit["type"] as? String else { continue }

            let usage = limit["usage"] as? Double ?? 0          // Total limit
            let currentValue = limit["currentValue"] as? Double ?? 0  // Used
            let percentage = limit["percentage"] as? Double ?? 0

            // Parse reset time (Unix timestamp in milliseconds)
            var resetDate: Date?
            if let nextResetTime = limit["nextResetTime"] as? Double {
                resetDate = Date(timeIntervalSince1970: nextResetTime / 1000.0)
            }

            switch type {
            case "TOKENS_LIMIT":
                // Main 5-hour token quota
                quotas.append(QuotaMetric(
                    id: "session",
                    name: "Tokens (5 hour)",
                    percentage: percentage,
                    used: currentValue,
                    limit: usage,
                    unit: "tokens",
                    resetDate: resetDate
                ))

            case "TIME_LIMIT":
                // Monthly web search/reader quota
                quotas.append(QuotaMetric(
                    id: "monthly_tools",
                    name: "Tools (Monthly)",
                    percentage: percentage,
                    used: currentValue,
                    limit: usage,
                    unit: "uses",
                    resetDate: resetDate
                ))

            default:
                // Handle any other quota types generically
                quotas.append(QuotaMetric(
                    id: type.lowercased(),
                    name: type.replacingOccurrences(of: "_", with: " ").capitalized,
                    percentage: percentage,
                    used: currentValue,
                    limit: usage,
                    unit: "units",
                    resetDate: resetDate
                ))
            }
        }

        // If no quotas found, return a placeholder
        if quotas.isEmpty {
            NSLog("ZaiProvider: No quotas found in response")
            quotas = [
                QuotaMetric(
                    id: "session",
                    name: "Tokens (5 hour)",
                    percentage: nil,
                    used: nil,
                    limit: nil,
                    unit: "tokens",
                    resetDate: nil
                )
            ]
        }

        let snapshot = UsageSnapshot(
            providerId: id,
            timestamp: Date(),
            quotas: quotas
        )

        NSLog("ZaiProvider: Parsed \(quotas.count) quotas")

        return snapshot
    }
}

// MARK: - Legacy Type Alias
typealias ZhipuWebProvider = ZaiProvider
