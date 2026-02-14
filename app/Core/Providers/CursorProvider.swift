import Foundation
import Combine

// MARK: - Cursor API Response Models

private struct CursorUsageSummary: Codable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let membershipType: String?
    let limitType: String?
    let isUnlimited: Bool?
    let autoModelSelectedDisplayMessage: String?
    let namedModelSelectedDisplayMessage: String?
    let individualUsage: CursorIndividualUsage?
    let teamUsage: CursorTeamUsage?
    
    enum CodingKeys: String, CodingKey {
        case billingCycleStart, billingCycleEnd, membershipType, limitType, isUnlimited
        case autoModelSelectedDisplayMessage, namedModelSelectedDisplayMessage
        case individualUsage, teamUsage
    }
}

private struct CursorIndividualUsage: Codable {
    let plan: CursorPlanUsage?
    let onDemand: CursorOnDemandUsage?
}

private struct CursorPlanBreakdown: Codable {
    let included: Int?
    let bonus: Int?
    let total: Int?
}

private struct CursorPlanUsage: Codable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?
    let totalPercentUsed: Double?
    let autoPercentUsed: Double?
    let apiPercentUsed: Double?
    let breakdown: CursorPlanBreakdown?
}

private struct CursorOnDemandUsage: Codable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?
}

private struct CursorTeamUsage: Codable {
    let onDemand: CursorOnDemandUsage?
}

private struct CursorUserInfo: Codable {
    let email: String?
    let emailVerified: Bool?
    let name: String?
    let sub: String?
    let createdAt: String?
    let updatedAt: String?
    let picture: String?
}

private struct CursorLegacyUsageResponse: Codable {
    let gpt4: CursorModelUsage?
    let startOfMonth: String?
    
    enum CodingKeys: String, CodingKey {
        case gpt4 = "gpt-4"
        case startOfMonth
    }
}

private struct CursorModelUsage: Codable {
    let numRequests: Int?
    let numRequestsTotal: Int?
    let numTokens: Int?
    let maxRequestUsage: Int?
    let maxTokenUsage: Int?
}

class CursorProvider: UsageProvider {
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
    
    private var sessionCookie: String = ""
    private var cachedUserId: String?
    private let credentialManager = CredentialManager.shared
    
    init() {
        loadCredentials()
    }
    
    func configure(credentials: ProviderCredentials) async throws {
        guard let cookie = credentials.cookie, !cookie.isEmpty else {
            throw ProviderError.invalidCredentials
        }
        
        sessionCookie = cookie
        
        try credentialManager.save(credentials)
        
        authState = .validating
        
        do {
            let userInfo = try await fetchUserInfo()
            cachedUserId = userInfo.sub
            authState = .authenticated
            NSLog("CursorProvider: Configured successfully as \(userInfo.email ?? "unknown")")
        } catch {
            authState = .failed(error.localizedDescription)
            throw error
        }
    }
    
    func fetchUsage() async throws -> UsageSnapshot {
        guard !sessionCookie.isEmpty else {
            throw ProviderError.notConfigured
        }
        
        async let usageSummaryTask = fetchUsageSummary()
        async let userInfoTask = fetchUserInfo()
        
        let usageSummary = try await usageSummaryTask
        let userInfo = try await userInfoTask
        cachedUserId = userInfo.sub
        
        var legacyUsage: CursorLegacyUsageResponse?
        if let userId = userInfo.sub {
            legacyUsage = try? await fetchLegacyUsage(userId: userId)
        }
        
        let snapshot = try parseUsageSummary(usageSummary, legacyUsage: legacyUsage, userInfo: userInfo)
        latestUsage = snapshot
        authState = .authenticated
        
        return snapshot
    }
    
    func clearCredentials() {
        sessionCookie = ""
        cachedUserId = nil
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
    
    private func loadCredentials() {
        if let credentials = credentialManager.load(for: id) {
            sessionCookie = credentials.cookie ?? ""
            
            if !sessionCookie.isEmpty {
                authState = .authenticated
                NSLog("CursorProvider: Loaded credentials from Keychain")
            }
        }
    }
    
    private func fetchUsageSummary() async throws -> CursorUsageSummary {
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
        
        NSLog("CursorProvider: Usage summary status \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            authState = .failed("Session expired")
            throw ProviderError.invalidCredentials
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ProviderError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CursorUsageSummary.self, from: data)
        } catch {
            NSLog("CursorProvider: Failed to decode usage summary: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                NSLog("CursorProvider: Raw response: \(raw)")
            }
            throw ProviderError.parseError("Failed to decode usage summary: \(error.localizedDescription)")
        }
    }
    
    private func fetchUserInfo() async throws -> CursorUserInfo {
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
        if let userInfo = try? decoder.decode(CursorUserInfo.self, from: data) {
            return userInfo
        }
        
        return CursorUserInfo(email: nil, emailVerified: nil, name: nil, sub: nil, createdAt: nil, updatedAt: nil, picture: nil)
    }
    
    private func fetchLegacyUsage(userId: String) async throws -> CursorLegacyUsageResponse {
        guard let url = URL(string: "https://cursor.com/api/usage?user=\(userId)") else {
            throw ProviderError.unknown("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(buildCookieHeader(from: sessionCookie), forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        NSLog("CursorProvider: Fetching legacy usage for user \(userId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.unknown("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            NSLog("CursorProvider: Legacy usage returned \(httpResponse.statusCode)")
            throw ProviderError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CursorLegacyUsageResponse.self, from: data)
    }
    
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
        
        return "WorkosCursorSessionToken=\(trimmed)"
    }
    
    private func parseUsageSummary(_ summary: CursorUsageSummary, legacyUsage: CursorLegacyUsageResponse?, userInfo: CursorUserInfo) throws -> UsageSnapshot {
        var quotas: [QuotaMetric] = []
        var totalCost: Decimal? = nil
        
        let billingEndDate = parseBillingEndDate(summary.billingCycleEnd)
        
        if let gpt4 = legacyUsage?.gpt4, gpt4.maxRequestUsage != nil {
            let requestsUsed = gpt4.numRequests ?? 0
            let requestsLimit = gpt4.maxRequestUsage ?? 0
            
            if requestsLimit > 0 {
                let requestsPercent = (Double(requestsUsed) / Double(requestsLimit)) * 100.0
                
                quotas.append(QuotaMetric(
                    id: "requests",
                    name: "GPT-4 Requests",
                    percentage: requestsPercent,
                    used: Double(requestsUsed),
                    limit: Double(requestsLimit),
                    unit: "requests",
                    resetDate: billingEndDate
                ))
            }
        }
        
        if let plan = summary.individualUsage?.plan, plan.enabled != false {
            let planUsedCents = Double(plan.used ?? 0)
            let planLimitCents = Double(plan.limit ?? 0)
            
            let planPercent: Double
            if planLimitCents > 0 {
                planPercent = (planUsedCents / planLimitCents) * 100.0
            } else if let apiPercent = plan.totalPercentUsed {
                planPercent = apiPercent <= 1.0 ? apiPercent * 100.0 : apiPercent
            } else if let autoPercent = plan.autoPercentUsed {
                planPercent = autoPercent <= 1.0 ? autoPercent * 100.0 : autoPercent
            } else {
                planPercent = 0
            }
            
            let planUsedUSD = planUsedCents / 100.0
            let planLimitUSD = planLimitCents / 100.0
            
            var planName = "Plan Usage"
            if let membershipType = summary.membershipType {
                planName = "\(membershipType) Plan"
            }
            
            quotas.append(QuotaMetric(
                id: "plan",
                name: planName,
                percentage: planPercent,
                used: planLimitUSD > 0 ? planUsedUSD : nil,
                limit: planLimitUSD > 0 ? planLimitUSD : nil,
                unit: planLimitUSD > 0 ? "USD" : "%",
                resetDate: billingEndDate
            ))
            
            if let breakdown = plan.breakdown {
                if let bonus = breakdown.bonus, bonus > 0 {
                    let bonusUSD = Double(bonus) / 100.0
                    quotas.append(QuotaMetric(
                        id: "bonus",
                        name: "Bonus Credits",
                        used: bonusUSD,
                        limit: nil,
                        unit: "USD",
                        resetDate: billingEndDate
                    ))
                }
            }
        }
        
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
        
        if let teamOnDemand = summary.teamUsage?.onDemand, teamOnDemand.enabled == true {
            let teamUsedCents = Double(teamOnDemand.used ?? 0)
            let teamLimitCents = teamOnDemand.limit.map { Double($0) }
            let teamUsedUSD = teamUsedCents / 100.0
            
            var teamPercent: Double? = nil
            var teamLimitUSD: Double? = nil
            
            if let limitCents = teamLimitCents, limitCents > 0 {
                teamPercent = (teamUsedCents / limitCents) * 100.0
                teamLimitUSD = limitCents / 100.0
            }
            
            quotas.append(QuotaMetric(
                id: "team_on_demand",
                name: "Team On-Demand",
                percentage: teamPercent,
                used: teamUsedUSD,
                limit: teamLimitUSD,
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
