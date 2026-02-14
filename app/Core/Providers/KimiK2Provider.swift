import Foundation
import Combine

private struct KimiK2CreditsResponse: Codable {
    let totalCreditsConsumed: Double?
    let totalCreditsUsed: Double?
    let creditsConsumed: Double?
    let consumedCredits: Double?
    let usedCredits: Double?
    let total: Double?
    let creditsRemaining: Double?
    let remainingCredits: Double?
    let availableCredits: Double?
    let creditsLeft: Double?
    let averageTokensPerRequest: Double?
    let averageTokens: Double?
    let updatedAt: String?
    let timestamp: String?
    
    enum CodingKeys: String, CodingKey {
        case totalCreditsConsumed
        case totalCreditsUsed
        case creditsConsumed
        case consumedCredits
        case usedCredits
        case total
        case creditsRemaining
        case remainingCredits
        case availableCredits
        case creditsLeft
        case averageTokensPerRequest
        case averageTokens
        case updatedAt
        case timestamp
    }
}

private struct KimiK2DataWrapper: Codable {
    let data: KimiK2CreditsResponse?
    let result: KimiK2CreditsResponse?
    let usage: KimiK2CreditsResponse?
    let credits: KimiK2CreditsResponse?
    let totalCreditsConsumed: Double?
    let totalCreditsUsed: Double?
    let creditsConsumed: Double?
    let creditsRemaining: Double?
    let remainingCredits: Double?
}

class KimiK2Provider: UsageProvider {
    let id = "kimik2"
    let name = "Kimi K2"
    let authMethod: AuthMethod = .apiKey
    
    @Published private(set) var authState: AuthState = .notConfigured
    @Published private(set) var latestUsage: UsageSnapshot?
    
    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> {
        $latestUsage.eraseToAnyPublisher()
    }
    
    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }
    
    let displayConfig = ProviderDisplayConfig.kimiK2
    
    var credentialInstructions: [String] {
        [
            "Go to kimi-k2.ai and sign in",
            "Navigate to your API settings or dashboard",
            "Generate or copy your API key",
            "Paste the API key below"
        ]
    }
    
    private var apiKey: String = ""
    private let credentialManager = CredentialManager.shared
    
    init() {
        loadCredentials()
    }
    
    func configure(credentials: ProviderCredentials) async throws {
        guard let key = credentials.apiKey, !key.isEmpty else {
            throw ProviderError.invalidCredentials
        }
        
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        
        try credentialManager.save(credentials)
        
        authState = .validating
        
        do {
            _ = try await fetchUsage()
            authState = .authenticated
            NSLog("KimiK2Provider: Configured successfully")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }
    
    func fetchUsage() async throws -> UsageSnapshot {
        guard !apiKey.isEmpty else {
            throw ProviderError.notConfigured
        }
        
        guard let url = URL(string: "https://kimi-k2.ai/api/user/credits") else {
            throw ProviderError.unknown("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        NSLog("KimiK2Provider: Fetching credits")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }
        
        NSLog("KimiK2Provider: Status \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            authState = .failed("Invalid API key")
            throw ProviderError.invalidCredentials
        }
        
        guard httpResponse.statusCode == 200 else {
            if let raw = String(data: data, encoding: .utf8) {
                NSLog("KimiK2Provider: Error response: \(raw)")
            }
            throw ProviderError.serverError(httpResponse.statusCode)
        }
        
        let snapshot = try parseCreditsResponse(data, httpResponse: httpResponse)
        latestUsage = snapshot
        authState = .authenticated
        
        return snapshot
    }
    
    func clearCredentials() {
        apiKey = ""
        latestUsage = nil
        authState = .notConfigured
        try? credentialManager.delete(for: id)
        NSLog("KimiK2Provider: Credentials cleared")
    }
    
    func validateCredentials() async -> Bool {
        guard !apiKey.isEmpty else { return false }
        
        do {
            _ = try await fetchUsage()
            return true
        } catch {
            return false
        }
    }
    
    private func loadCredentials() {
        if let credentials = credentialManager.load(for: id) {
            apiKey = credentials.apiKey ?? ""
            
            if !apiKey.isEmpty {
                authState = .authenticated
                NSLog("KimiK2Provider: Loaded credentials from Keychain")
            }
        }
    }
    
    private func parseCreditsResponse(_ data: Data, httpResponse: HTTPURLResponse) throws -> UsageSnapshot {
        var consumed: Double = 0
        var remaining: Double = 0
        var averageTokens: Double? = nil
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            consumed = extractConsumed(from: json)
            remaining = extractRemaining(from: json, httpResponse: httpResponse)
            averageTokens = extractAverageTokens(from: json)
        }
        
        if remaining == 0, let headerRemaining = httpResponse.value(forHTTPHeaderField: "x-credits-remaining") {
            remaining = Double(headerRemaining) ?? 0
        }
        
        remaining = max(0, remaining)
        
        let total = consumed + remaining
        let percentage = total > 0 ? min(100, max(0, (consumed / total) * 100)) : 0
        
        let quota = QuotaMetric(
            id: "credits",
            name: "Credits",
            percentage: percentage,
            used: consumed,
            limit: total > 0 ? total : nil,
            unit: "credits"
        )
        
        let snapshot = UsageSnapshot(
            providerId: id,
            timestamp: Date(),
            quotas: [quota]
        )
        
        NSLog("KimiK2Provider: consumed=\(consumed), remaining=\(remaining), percentage=\(percentage)")
        return snapshot
    }
    
    private func extractConsumed(from json: [String: Any]) -> Double {
        let contexts = buildContexts(from: json)
        
        let consumedKeys = [
            "total_credits_consumed", "totalCreditsConsumed",
            "total_credits_used", "totalCreditsUsed",
            "credits_consumed", "creditsConsumed",
            "consumedCredits", "usedCredits",
            "total"
        ]
        
        for context in contexts {
            for key in consumedKeys {
                if let value = extractDouble(from: context, key: key) {
                    return value
                }
            }
            
            if let usage = context["usage"] as? [String: Any] {
                if let value = extractDouble(from: usage, key: "total") { return value }
                if let value = extractDouble(from: usage, key: "consumed") { return value }
            }
        }
        
        return 0
    }
    
    private func extractRemaining(from json: [String: Any], httpResponse: HTTPURLResponse) -> Double {
        let contexts = buildContexts(from: json)
        
        let remainingKeys = [
            "credits_remaining", "creditsRemaining",
            "remaining_credits", "remainingCredits",
            "available_credits", "availableCredits",
            "credits_left", "creditsLeft"
        ]
        
        for context in contexts {
            for key in remainingKeys {
                if let value = extractDouble(from: context, key: key) {
                    return value
                }
            }
            
            if let usage = context["usage"] as? [String: Any] {
                if let value = extractDouble(from: usage, key: "credits_remaining") { return value }
                if let value = extractDouble(from: usage, key: "remaining") { return value }
            }
        }
        
        return 0
    }
    
    private func extractAverageTokens(from json: [String: Any]) -> Double? {
        let contexts = buildContexts(from: json)
        
        let tokenKeys = [
            "average_tokens_per_request", "averageTokensPerRequest",
            "average_tokens", "averageTokens",
            "avg_tokens", "avgTokens"
        ]
        
        for context in contexts {
            for key in tokenKeys {
                if let value = extractDouble(from: context, key: key) {
                    return value
                }
            }
        }
        
        return nil
    }
    
    private func buildContexts(from json: [String: Any]) -> [[String: Any]] {
        var contexts: [[String: Any]] = [json]
        
        if let data = json["data"] as? [String: Any] {
            contexts.append(data)
            if let dataUsage = data["usage"] as? [String: Any] { contexts.append(dataUsage) }
            if let dataCredits = data["credits"] as? [String: Any] { contexts.append(dataCredits) }
        }
        
        if let result = json["result"] as? [String: Any] {
            contexts.append(result)
            if let resultUsage = result["usage"] as? [String: Any] { contexts.append(resultUsage) }
            if let resultCredits = result["credits"] as? [String: Any] { contexts.append(resultCredits) }
        }
        
        if let usage = json["usage"] as? [String: Any] { contexts.append(usage) }
        if let credits = json["credits"] as? [String: Any] { contexts.append(credits) }
        
        return contexts
    }
    
    private func extractDouble(from json: [String: Any], key: String) -> Double? {
        guard let value = json[key] else { return nil }
        
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        
        return nil
    }
}
