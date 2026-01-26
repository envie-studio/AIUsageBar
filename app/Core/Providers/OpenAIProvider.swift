import Foundation
import Combine

/// Provider for OpenAI ChatGPT Plus web usage tracking
/// Note: This requires reverse engineering the ChatGPT web interface
/// to find the actual usage/quota endpoints
class OpenAIWebProvider: UsageProvider {
    // MARK: - UsageProvider Protocol

    let id = "openai"
    let name = "OpenAI"
    let authMethod: AuthMethod = .cookie

    @Published private(set) var authState: AuthState = .notConfigured
    @Published private(set) var latestUsage: UsageSnapshot?

    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> {
        $latestUsage.eraseToAnyPublisher()
    }

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    let displayConfig = ProviderDisplayConfig.openai

    var credentialInstructions: [String] {
        [
            "1. Go to chatgpt.com and sign in",
            "2. Press F12 (or Cmd+Option+I)",
            "3. Go to Network tab",
            "4. Click on model picker (shows reset time)",
            "5. Look for requests to 'backend-api'",
            "6. Find 'Cookie' in Request Headers",
            "7. Copy full cookie value"
        ]
    }

    // MARK: - Private Properties

    private var sessionCookie: String = ""
    private var accessToken: String?
    private let credentialManager = CredentialManager.shared

    // Known endpoints (need verification):
    // - chatgpt.com/backend-api/conversation
    // - chatgpt.com/api/auth/session
    // - chatgpt.com/backend-api/models (shows model limits)

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
        accessToken = credentials.bearerToken

        // Save to keychain
        try credentialManager.save(credentials)

        authState = .validating

        do {
            // Try to fetch session to validate
            accessToken = try await fetchAccessToken()
            authState = .authenticated
            NSLog("OpenAIWebProvider: Configured successfully")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard !sessionCookie.isEmpty else {
            throw ProviderError.notConfigured
        }

        // Ensure we have an access token
        if accessToken == nil {
            accessToken = try await fetchAccessToken()
        }

        // TODO: This endpoint needs to be discovered by inspecting
        // network traffic when clicking on the model picker in ChatGPT
        // The model picker shows reset times, so there must be an endpoint

        // Placeholder: Try to fetch from models endpoint
        let quotas = try await fetchModelLimits()

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
        accessToken = nil
        latestUsage = nil
        authState = .notConfigured

        try? credentialManager.delete(for: id)
        NSLog("OpenAIWebProvider: Credentials cleared")
    }

    func validateCredentials() async -> Bool {
        guard !sessionCookie.isEmpty else { return false }

        do {
            _ = try await fetchAccessToken()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func loadCredentials() {
        if let credentials = credentialManager.load(for: id) {
            sessionCookie = credentials.cookie ?? ""
            accessToken = credentials.bearerToken

            if !sessionCookie.isEmpty {
                authState = .authenticated
                NSLog("OpenAIWebProvider: Loaded credentials from Keychain")
            }
        }
    }

    private func fetchAccessToken() async throws -> String {
        // Fetch JWT from session endpoint
        guard let url = URL(string: "https://chatgpt.com/api/auth/session") else {
            throw ProviderError.unknown("Invalid session URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        NSLog("OpenAIWebProvider: Fetching session...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            authState = .failed("Session expired")
            throw ProviderError.invalidCredentials
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderError.serverError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["accessToken"] as? String else {
            throw ProviderError.parseError("Could not extract access token")
        }

        NSLog("OpenAIWebProvider: Got access token")
        return token
    }

    private func fetchModelLimits() async throws -> [QuotaMetric] {
        // TODO: Discover the actual endpoint for model limits/usage
        // This is a placeholder based on known information:
        // - GPT-4o: 150 messages/3hr
        // - o3: 100/week
        // - o4-mini: 300/day

        // Try the models endpoint
        guard let url = URL(string: "https://chatgpt.com/backend-api/models") else {
            throw ProviderError.unknown("Invalid models URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        NSLog("OpenAIWebProvider: Fetching model limits...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            // If this fails, the endpoint might be different
            NSLog("OpenAIWebProvider: Models endpoint returned \(httpResponse.statusCode)")
            NSLog("OpenAIWebProvider: Response: \(String(data: data, encoding: .utf8) ?? "nil")")

            // Return placeholder quotas - user needs to help discover the actual endpoint
            return [
                QuotaMetric(
                    id: "gpt4o",
                    name: "GPT-4o (3hr limit)",
                    percentage: nil,
                    used: nil,
                    limit: 150,
                    unit: "messages",
                    resetDate: nil
                )
            ]
        }

        // Parse the response - structure TBD based on actual response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid JSON")
        }

        NSLog("OpenAIWebProvider: Models response: \(json)")

        // TODO: Parse actual response structure
        // For now return placeholder
        return [
            QuotaMetric(
                id: "gpt4o",
                name: "GPT-4o (3hr limit)",
                percentage: nil,
                used: nil,
                limit: 150,
                unit: "messages",
                resetDate: nil
            )
        ]
    }
}
