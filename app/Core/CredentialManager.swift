import Foundation
import Security

/// Manages secure storage of provider credentials using Keychain
class CredentialManager {
    static let shared = CredentialManager()

    private let servicePrefix = "com.claudeusagebar"

    private init() {}

    // MARK: - Public API

    /// Save credentials for a provider
    func save(_ credentials: ProviderCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let key = keychainKey(for: credentials.providerId)

        // Delete existing item if present
        try? delete(for: credentials.providerId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            throw CredentialError.saveFailed(status)
        }

        NSLog("CredentialManager: Saved credentials for \(credentials.providerId)")
    }

    /// Load credentials for a provider
    func load(for providerId: String) -> ProviderCredentials? {
        let key = keychainKey(for: providerId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode(ProviderCredentials.self, from: data) else {
            return nil
        }

        return credentials
    }

    /// Delete credentials for a provider
    func delete(for providerId: String) throws {
        let key = keychainKey(for: providerId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw CredentialError.deleteFailed(status)
        }

        NSLog("CredentialManager: Deleted credentials for \(providerId)")
    }

    /// Check if credentials exist for a provider
    func hasCredentials(for providerId: String) -> Bool {
        return load(for: providerId) != nil
    }

    /// Delete all credentials
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw CredentialError.deleteFailed(status)
        }

        NSLog("CredentialManager: Deleted all credentials")
    }

    // MARK: - Legacy Migration (from UserDefaults)

    /// Migrate legacy Claude cookie from UserDefaults to Keychain
    func migrateLegacyClaudeCookie() {
        let defaults = UserDefaults.standard
        guard let legacyCookie = defaults.string(forKey: "claude_session_cookie"),
              !legacyCookie.isEmpty else {
            return
        }

        // Check if already migrated
        if hasCredentials(for: "claude") {
            return
        }

        let credentials = ProviderCredentials(
            providerId: "claude",
            cookie: legacyCookie
        )

        do {
            try save(credentials)
            // Remove from UserDefaults after successful migration
            defaults.removeObject(forKey: "claude_session_cookie")
            defaults.synchronize()
            NSLog("CredentialManager: Migrated legacy Claude cookie to Keychain")
        } catch {
            NSLog("CredentialManager: Failed to migrate legacy cookie: \(error)")
        }
    }

    // MARK: - Private

    private func keychainKey(for providerId: String) -> String {
        return "\(servicePrefix).\(providerId)"
    }
}

/// Credential storage errors
enum CredentialError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save credentials: \(status)"
        case .loadFailed(let status):
            return "Failed to load credentials: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete credentials: \(status)"
        }
    }
}
