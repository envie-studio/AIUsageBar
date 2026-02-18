import Foundation
import Combine

/// Provider for OpenAI Codex (chatgpt.com/codex) usage tracking
class CodexProvider: UsageProvider {
    // MARK: - UsageProvider Protocol

    let id = "codex"
    let name = "Codex"
    let authMethod: AuthMethod = .cookie

    @Published private(set) var authState: AuthState = .notConfigured
    @Published private(set) var latestUsage: UsageSnapshot?

    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> {
        $latestUsage.eraseToAnyPublisher()
    }

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    let displayConfig = ProviderDisplayConfig.codex

    var credentialInstructions: [String] {
        [
            "1. Go to chatgpt.com/codex",
            "2. Press F12 (or Cmd+Option+I)",
            "3. Go to Network tab",
            "4. Look for 'wham/usage' request",
            "5. Find 'Cookie' in Request Headers",
            "6. Copy full cookie value"
        ]
    }

    // MARK: - Private Properties

    private var sessionCookie: String = ""
    private var deviceId: String = ""
    private var accessToken: String = ""
    private let credentialManager = CredentialManager.shared

    // MARK: - Initialization

    init() {
        loadCredentials()
    }

    // MARK: - Public Methods

    func configure(credentials: ProviderCredentials) async throws {
        print("[CodexProvider] configure() called")
        NSLog("CodexProvider: configure() called")

        guard let cookie = credentials.cookie, !cookie.isEmpty else {
            print("[CodexProvider] ERROR: Empty or nil cookie")
            throw ProviderError.invalidCredentials
        }

        print("[CodexProvider] Cookie length: \(cookie.count)")
        NSLog("CodexProvider: Cookie length: \(cookie.count)")

        sessionCookie = cookie

        // Extract device ID from cookie (must match oai-did cookie value)
        if let extractedId = extractDeviceId(from: cookie) {
            deviceId = extractedId
            print("[CodexProvider] Extracted device ID from cookie: \(deviceId)")
        } else if let existingDeviceId = credentials.additionalData?["deviceId"], !existingDeviceId.isEmpty {
            deviceId = existingDeviceId
            print("[CodexProvider] Using existing device ID: \(deviceId)")
        } else {
            deviceId = UUID().uuidString
            print("[CodexProvider] Generated new device ID: \(deviceId)")
        }
        NSLog("CodexProvider: Using device ID: \(deviceId)")

        // Fetch access token using cookie
        accessToken = try await fetchAccessToken()
        print("[CodexProvider] Access token obtained")

        // Save to keychain with deviceId
        var credentialsWithDeviceId = credentials
        var additionalData = credentials.additionalData ?? [:]
        additionalData["deviceId"] = deviceId
        credentialsWithDeviceId = ProviderCredentials(
            providerId: id,
            cookie: cookie,
            additionalData: additionalData
        )
        try credentialManager.save(credentialsWithDeviceId)

        // Validate by fetching usage
        authState = .validating

        do {
            _ = try await fetchUsage()
            authState = .authenticated
            NSLog("CodexProvider: Configured successfully")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard !sessionCookie.isEmpty else {
            throw ProviderError.notConfigured
        }

        // Lazy token refresh - only fetch when needed
        if accessToken.isEmpty {
            NSLog("CodexProvider: Access token empty, fetching fresh token...")
            accessToken = try await fetchAccessToken()
        }

        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else {
            throw ProviderError.unknown("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
        request.setValue("https://chatgpt.com/codex", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue(deviceId, forHTTPHeaderField: "oai-device-id")
        request.setValue("en-US", forHTTPHeaderField: "oai-language")

        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        print("[CodexProvider] Fetching usage with device ID: \(deviceId)")
        NSLog("CodexProvider: Fetching usage with device ID: \(deviceId)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        print("[CodexProvider] Response status: \(httpResponse.statusCode)")
        NSLog("CodexProvider: Status \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("[CodexProvider] Auth error response: \(responseBody)")
            NSLog("CodexProvider: Auth error response: \(responseBody)")
            
            // Try refreshing token once on auth error
            NSLog("CodexProvider: Attempting token refresh due to auth error...")
            do {
                accessToken = try await fetchAccessToken()
                // Retry the request with fresh token
                var retryRequest = URLRequest(url: url)
                retryRequest.httpMethod = "GET"
                retryRequest.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
                retryRequest.setValue("*/*", forHTTPHeaderField: "Accept")
                retryRequest.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
                retryRequest.setValue("https://chatgpt.com/codex", forHTTPHeaderField: "Referer")
                retryRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                retryRequest.setValue(deviceId, forHTTPHeaderField: "oai-device-id")
                retryRequest.setValue("en-US", forHTTPHeaderField: "oai-language")
                retryRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw ProviderError.unknown("Invalid retry response")
                }
                
                if retryHttpResponse.statusCode == 401 || retryHttpResponse.statusCode == 403 {
                    authState = .failed("Session expired")
                    throw ProviderError.invalidCredentials
                }
                
                guard retryHttpResponse.statusCode == 200 else {
                    throw ProviderError.serverError(retryHttpResponse.statusCode)
                }
                
                let snapshot = try parseUsageData(retryData)
                latestUsage = snapshot
                authState = .authenticated
                return snapshot
            } catch {
                authState = .failed("Session expired")
                throw ProviderError.invalidCredentials
            }
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("[CodexProvider] Error response: \(responseBody)")
            NSLog("CodexProvider: Error response: \(responseBody)")
            throw ProviderError.serverError(httpResponse.statusCode)
        }

        let snapshot = try parseUsageData(data)
        latestUsage = snapshot
        authState = .authenticated

        return snapshot
    }

    func clearCredentials() {
        sessionCookie = ""
        deviceId = ""
        accessToken = ""
        latestUsage = nil
        authState = .notConfigured

        try? credentialManager.delete(for: id)
        NSLog("CodexProvider: Credentials cleared")
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
            deviceId = credentials.additionalData?["deviceId"] ?? ""

            // Extract deviceId from cookie if not stored
            if deviceId.isEmpty, let cookie = credentials.cookie {
                deviceId = extractDeviceId(from: cookie) ?? UUID().uuidString
            }

            if !sessionCookie.isEmpty {
                authState = .authenticated
                NSLog("CodexProvider: Loaded credentials from Keychain")
            }
        }
    }

    private func parseUsageData(_ data: Data) throws -> UsageSnapshot {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid JSON")
        }

        NSLog("CodexProvider: Parsing usage data...")

        var quotas: [QuotaMetric] = []

        // Parse primary rate limit (5-hour window)
        if let rateLimit = json["rate_limit"] as? [String: Any],
           let primaryWindow = rateLimit["primary_window"] as? [String: Any] {
            let usedPercent = primaryWindow["used_percent"] as? Double ?? 0
            let resetDate = parseResetDate(from: primaryWindow["reset_at"])

            quotas.append(QuotaMetric(
                id: "primary",
                name: "Primary (5 hour)",
                percentage: usedPercent,
                unit: "%",
                resetDate: resetDate
            ))

            // Parse secondary rate limit (7-day window)
            if let secondaryWindow = rateLimit["secondary_window"] as? [String: Any] {
                let secondaryUsedPercent = secondaryWindow["used_percent"] as? Double ?? 0
                let secondaryResetDate = parseResetDate(from: secondaryWindow["reset_at"])

                quotas.append(QuotaMetric(
                    id: "weekly",
                    name: "Weekly (7 day)",
                    percentage: secondaryUsedPercent,
                    unit: "%",
                    resetDate: secondaryResetDate
                ))
            }
        }

        // Parse code review rate limit (weekly)
        if let codeReviewLimit = json["code_review_rate_limit"] as? [String: Any],
           let primaryWindow = codeReviewLimit["primary_window"] as? [String: Any] {
            let usedPercent = primaryWindow["used_percent"] as? Double ?? 0
            let resetDate = parseResetDate(from: primaryWindow["reset_at"])

            quotas.append(QuotaMetric(
                id: "code_review",
                name: "Code Review (weekly)",
                percentage: usedPercent,
                unit: "%",
                resetDate: resetDate
            ))
        }

        let snapshot = UsageSnapshot(
            providerId: id,
            timestamp: Date(),
            quotas: quotas
        )

        NSLog("CodexProvider: Parsed \(quotas.count) quotas")

        return snapshot
    }

    private func parseResetDate(from value: Any?) -> Date? {
        // API returns Unix timestamp in seconds
        if let timestamp = value as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        return nil
    }

    private func fetchAccessToken() async throws -> String {
        guard let url = URL(string: "https://chatgpt.com/api/auth/session") else {
            throw ProviderError.unknown("Invalid session URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.invalidCredentials
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["accessToken"] as? String else {
            throw ProviderError.parseError("Could not extract access token")
        }

        print("[CodexProvider] Fetched access token")
        return token
    }

    private func extractDeviceId(from cookie: String) -> String? {
        // Look for oai-did=<uuid> in cookie string
        // Handle both "; " and ";" separators
        let components = cookie.components(separatedBy: ";")
        print("[CodexProvider] Parsing \(components.count) cookie components")

        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            // Log first 30 chars of each component to help debug
            let preview = String(trimmed.prefix(30))
            if trimmed.hasPrefix("oai-did=") {
                let deviceId = String(trimmed.dropFirst("oai-did=".count))
                print("[CodexProvider] Found oai-did: \(deviceId)")
                NSLog("CodexProvider: Extracted device ID: \(deviceId)")
                return deviceId
            }
        }
        print("[CodexProvider] oai-did NOT found in any cookie component")
        NSLog("CodexProvider: Could not find oai-did in cookie")
        return nil
    }
}
