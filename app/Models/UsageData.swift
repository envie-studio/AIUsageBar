import Foundation

/// Authentication method for a provider
enum AuthMethod {
    case cookie          // Browser session cookie (Claude, OpenAI web)
    case apiKey          // API key for official APIs
    case bearerToken     // Bearer token authentication
    case none            // No authentication required
}

/// Represents a single quota metric (session, weekly, tokens, etc.)
struct QuotaMetric: Identifiable {
    let id: String
    let name: String
    let percentage: Double?      // 0-100 if applicable
    let used: Double?            // Absolute value used
    let limit: Double?           // Absolute limit
    let unit: String             // "tokens", "USD", "%", "messages"
    let resetDate: Date?

    init(id: String = UUID().uuidString,
         name: String,
         percentage: Double? = nil,
         used: Double? = nil,
         limit: Double? = nil,
         unit: String = "%",
         resetDate: Date? = nil) {
        self.id = id
        self.name = name
        self.percentage = percentage
        self.used = used
        self.limit = limit
        self.unit = unit
        self.resetDate = resetDate
    }

    /// Computed percentage from used/limit if percentage not directly provided
    var computedPercentage: Double {
        if let pct = percentage {
            return pct
        }
        guard let used = used, let limit = limit, limit > 0 else {
            return 0
        }
        return (used / limit) * 100
    }
}

/// Snapshot of usage data from a provider at a point in time
struct UsageSnapshot {
    let providerId: String
    let timestamp: Date
    var quotas: [QuotaMetric]
    var inputTokens: Int?
    var outputTokens: Int?
    var totalCost: Decimal?      // In USD

    init(providerId: String,
         timestamp: Date = Date(),
         quotas: [QuotaMetric] = [],
         inputTokens: Int? = nil,
         outputTokens: Int? = nil,
         totalCost: Decimal? = nil) {
        self.providerId = providerId
        self.timestamp = timestamp
        self.quotas = quotas
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalCost = totalCost
    }

    /// Returns the primary quota (usually the highest usage percentage)
    var primaryQuota: QuotaMetric? {
        quotas.max(by: { $0.computedPercentage < $1.computedPercentage })
    }

    /// Returns the highest usage percentage across all quotas
    var maxUsagePercentage: Double {
        quotas.map { $0.computedPercentage }.max() ?? 0
    }

    /// Returns the preferred quota based on user preference
    /// - Parameter quotaId: The preferred quota ID, or nil/"auto" for highest percentage
    /// - Returns: The matching quota, or primaryQuota as fallback
    func preferredQuota(quotaId: String?) -> QuotaMetric? {
        // If nil or "auto", return highest (current behavior)
        guard let id = quotaId, id != "auto" else {
            return primaryQuota
        }
        // Find matching quota, fallback to primary
        return quotas.first { $0.id == id } ?? primaryQuota
    }
}

/// Provider authentication state
enum AuthState {
    case notConfigured
    case validating
    case authenticated
    case failed(String)

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}

/// Credentials for a provider
struct ProviderCredentials: Codable {
    let providerId: String
    var cookie: String?
    var apiKey: String?
    var bearerToken: String?
    var organizationId: String?  // For Claude web API
    var additionalData: [String: String]?

    init(providerId: String,
         cookie: String? = nil,
         apiKey: String? = nil,
         bearerToken: String? = nil,
         organizationId: String? = nil,
         additionalData: [String: String]? = nil) {
        self.providerId = providerId
        self.cookie = cookie
        self.apiKey = apiKey
        self.bearerToken = bearerToken
        self.organizationId = organizationId
        self.additionalData = additionalData
    }
}

/// Configuration for displaying a provider in the UI
struct ProviderDisplayConfig {
    let primaryColor: String     // Hex color code
    let iconName: String         // SF Symbol or custom icon name
    let shortName: String        // Short display name (e.g., "Claude", "GPT")

    static let claude = ProviderDisplayConfig(
        primaryColor: "#E57C4A",
        iconName: "sparkles",
        shortName: "Claude"
    )

    static let openai = ProviderDisplayConfig(
        primaryColor: "#00A67E",
        iconName: "brain",
        shortName: "GPT"
    )

    static let zhipu = ProviderDisplayConfig(
        primaryColor: "#4A90D9",
        iconName: "sparkle",
        shortName: "GLM"
    )

    static let zai = ProviderDisplayConfig(
        primaryColor: "#6366F1",  // Indigo/purple for Z.ai branding
        iconName: "bolt.fill",
        shortName: "Z.ai"
    )

    static let codex = ProviderDisplayConfig(
        primaryColor: "#10A37F",  // OpenAI green
        iconName: "chevron.left.forwardslash.chevron.right",
        shortName: "Codex"
    )

    static let cursor = ProviderDisplayConfig(
        primaryColor: "#00B4D8",  // Cursor teal/cyan
        iconName: "cursorarrow.rays",
        shortName: "Cursor"
    )

    static let kimiK2 = ProviderDisplayConfig(
        primaryColor: "#4C00FF",  // Kimi purple
        iconName: "sparkle",
        shortName: "Kimi K2"
    )
}
