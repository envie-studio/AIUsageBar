import Foundation
import Combine

private struct KimiUsageResponse: Codable {
    let usages: [KimiUsage]?
}

private struct KimiUsage: Codable {
    let scope: String?
    let detail: KimiUsageDetail?
    let limits: [KimiLimit]?
}

private struct KimiUsageDetail: Codable {
    let limit: String?
    let used: String?
    let remaining: String?
    let resetTime: String?
}

private struct KimiLimit: Codable {
    let window: KimiWindow?
    let detail: KimiUsageDetail?
}

private struct KimiWindow: Codable {
    let duration: Int?
    let timeUnit: String?
}

class KimiProvider: UsageProvider {
    let id = "kimi"
    let name = "Kimi"
    let authMethod: AuthMethod = .cookie
    
    @Published private(set) var authState: AuthState = .notConfigured
    @Published private(set) var latestUsage: UsageSnapshot?
    
    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> {
        $latestUsage.eraseToAnyPublisher()
    }
    
    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }
    
    let displayConfig = ProviderDisplayConfig.kimi
    
    var credentialInstructions: [String] {
        [
            "1. Go to kimi.com/code/console",
            "2. Press F12 (or Cmd+Option+I)",
            "3. Go to Application → Cookies",
            "4. Copy the 'kimi-auth' cookie value",
            "5. Paste the token below"
        ]
    }
    
    private var authToken: String = ""
    private let credentialManager = CredentialManager.shared
    
    init() {
        loadCredentials()
    }
    
    func configure(credentials: ProviderCredentials) async throws {
        NSLog("KimiProvider: configure() called")
        
        guard let token = credentials.cookie, !token.isEmpty else {
            NSLog("KimiProvider: ERROR: Empty token")
            throw ProviderError.invalidCredentials
        }
        
        authToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        
        NSLog("KimiProvider: Token length: \(authToken.count)")
        
        try credentialManager.save(credentials)
        
        authState = .validating
        
        do {
            _ = try await fetchUsage()
            authState = .authenticated
            NSLog("KimiProvider: Configured successfully")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }
    
    func fetchUsage() async throws -> UsageSnapshot {
        guard !authToken.isEmpty else {
            throw ProviderError.notConfigured
        }
        
        guard let url = URL(string: "https://www.kimi.com/apiv2/kimi.gateway.billing.v1.BillingService/GetUsages") else {
            throw ProviderError.unknown("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.kimi.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.kimi.com/code/console", forHTTPHeaderField: "Referer")
        request.httpBody = "{}".data(using: .utf8)
        
        NSLog("KimiProvider: Fetching usage")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }
        
        NSLog("KimiProvider: Status \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            authState = .failed("Invalid or expired token")
            throw ProviderError.invalidCredentials
        }
        
        guard httpResponse.statusCode == 200 else {
            if let raw = String(data: data, encoding: .utf8) {
                NSLog("KimiProvider: Error response: \(raw)")
            }
            throw ProviderError.serverError(httpResponse.statusCode)
        }
        
        let snapshot = try parseUsageData(data)
        latestUsage = snapshot
        authState = .authenticated
        
        return snapshot
    }
    
    func clearCredentials() {
        authToken = ""
        latestUsage = nil
        authState = .notConfigured
        try? credentialManager.delete(for: id)
        NSLog("KimiProvider: Credentials cleared")
    }
    
    func validateCredentials() async -> Bool {
        guard !authToken.isEmpty else { return false }
        
        do {
            _ = try await fetchUsage()
            return true
        } catch {
            return false
        }
    }
    
    private func loadCredentials() {
        if let credentials = credentialManager.load(for: id) {
            authToken = credentials.cookie ?? ""
            
            if !authToken.isEmpty {
                authState = .authenticated
                NSLog("KimiProvider: Loaded credentials from Keychain")
            }
        }
    }
    
    private func parseUsageData(_ data: Data) throws -> UsageSnapshot {
        let response = try JSONDecoder().decode(KimiUsageResponse.self, from: data)
        
        var quotas: [QuotaMetric] = []
        
        guard let usages = response.usages else {
            throw ProviderError.parseError("No usage data in response")
        }
        
        for usage in usages {
            guard usage.scope == "FEATURE_CODING" else { continue }
            
            if let detail = usage.detail {
                let weeklyQuota = parseDetail(detail, name: "Weekly", id: "weekly")
                quotas.append(weeklyQuota)
            }
            
            if let limits = usage.limits {
                for limit in limits {
                    if let detail = limit.detail,
                       let window = limit.window,
                       window.timeUnit == "TIME_UNIT_MINUTE",
                       window.duration == 300 {
                        let rateLimitQuota = parseDetail(detail, name: "Rate Limit (5h)", id: "rateLimit")
                        quotas.append(rateLimitQuota)
                    }
                }
            }
        }
        
        let snapshot = UsageSnapshot(
            providerId: id,
            timestamp: Date(),
            quotas: quotas
        )
        
        NSLog("KimiProvider: Parsed \(quotas.count) quotas")
        return snapshot
    }
    
    private func parseDetail(_ detail: KimiUsageDetail, name: String, id: String) -> QuotaMetric {
        let limit = Double(detail.limit ?? "0") ?? 0
        let used = Double(detail.used ?? "0") ?? 0
        let remaining = Double(detail.remaining ?? "0") ?? 0
        
        let percentage: Double
        if limit > 0 {
            percentage = (used / limit) * 100
        } else {
            percentage = 0
        }
        
        var resetDate: Date? = nil
        if let resetTimeStr = detail.resetTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            resetDate = formatter.date(from: resetTimeStr)
        }
        
        return QuotaMetric(
            id: id,
            name: name,
            percentage: percentage,
            used: used,
            limit: limit,
            unit: "requests",
            resetDate: resetDate
        )
    }
}
