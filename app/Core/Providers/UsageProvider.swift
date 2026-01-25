import Foundation
import Combine

/// Protocol that all usage providers must implement
protocol UsageProvider: AnyObject {
    /// Unique identifier for this provider
    var id: String { get }

    /// Display name for the provider
    var name: String { get }

    /// Authentication method used by this provider
    var authMethod: AuthMethod { get }

    /// Current authentication state
    var authState: AuthState { get }

    /// Most recent usage data
    var latestUsage: UsageSnapshot? { get }

    /// Publisher for usage updates
    var usagePublisher: AnyPublisher<UsageSnapshot?, Never> { get }

    /// Publisher for auth state changes
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }

    /// Display configuration (colors, icons)
    var displayConfig: ProviderDisplayConfig { get }

    /// Instructions for obtaining credentials
    var credentialInstructions: [String] { get }

    /// Whether the provider is currently authenticated
    var isAuthenticated: Bool { get }

    /// Configure the provider with credentials
    func configure(credentials: ProviderCredentials) async throws

    /// Fetch current usage data
    func fetchUsage() async throws -> UsageSnapshot

    /// Clear stored credentials
    func clearCredentials()

    /// Validate current credentials
    func validateCredentials() async -> Bool
}

/// Default implementations
extension UsageProvider {
    var isAuthenticated: Bool {
        return authState.isAuthenticated
    }
}

/// Errors that providers can throw
enum ProviderError: LocalizedError {
    case notConfigured
    case invalidCredentials
    case networkError(Error)
    case parseError(String)
    case rateLimited
    case serverError(Int)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Provider not configured"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .rateLimited:
            return "Rate limited"
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        case .unknown(let message):
            return message
        }
    }
}

/// Provider registration and discovery
class ProviderRegistry {
    static let shared = ProviderRegistry()

    private var providers: [String: UsageProvider] = [:]

    private init() {}

    func register(_ provider: UsageProvider) {
        providers[provider.id] = provider
    }

    func provider(for id: String) -> UsageProvider? {
        return providers[id]
    }

    var allProviders: [UsageProvider] {
        return Array(providers.values).sorted { $0.name < $1.name }
    }

    var enabledProviders: [UsageProvider] {
        let settings = AppSettings.shared
        return allProviders.filter { settings.isProviderEnabled($0.id) }
    }

    var authenticatedProviders: [UsageProvider] {
        return allProviders.filter { $0.isAuthenticated }
    }
}
