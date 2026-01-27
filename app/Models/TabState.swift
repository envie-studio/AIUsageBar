import SwiftUI
import Combine

/// Tab selection state for the main popup
enum SelectedTab: Equatable {
    case overview
    case provider(String)  // Provider ID
    
    var isOverview: Bool {
        if case .overview = self { return true }
        return false
    }
    
    var providerId: String? {
        if case .provider(let id) = self { return id }
        return nil
    }
}

/// Manages tab state and persistence
class TabState: ObservableObject {
    static let shared = TabState()
    
    @Published var selectedTab: SelectedTab = .overview {
        didSet {
            saveLastTab()
        }
    }
    
    @Published var defaultTab: SelectedTab = .overview {
        didSet {
            saveSettings()
        }
    }
    
    private let defaults = UserDefaults.standard
    private let lastTabKey = "last_opened_tab"
    private let defaultTabKey = "default_tab"
    private let pinnedProvidersKey = "pinned_providers"
    
    @Published var pinnedProviders: Set<String> = [] {
        didSet {
            savePinnedProviders()
        }
    }
    
    private init() {
        loadSettings()
    }
    
    func selectTab(_ tab: SelectedTab) {
        selectedTab = tab
    }
    
    func selectOverview() {
        selectedTab = .overview
    }
    
    func selectProvider(_ providerId: String) {
        selectedTab = .provider(providerId)
    }
    
    func isPinned(_ providerId: String) -> Bool {
        return pinnedProviders.contains(providerId)
    }
    
    func togglePin(_ providerId: String) {
        if pinnedProviders.contains(providerId) {
            pinnedProviders.remove(providerId)
        } else {
            pinnedProviders.insert(providerId)
        }
    }
    
    func setAsDefault(_ tab: SelectedTab) {
        defaultTab = tab
    }
    
    private func saveLastTab() {
        switch selectedTab {
        case .overview:
            defaults.set("overview", forKey: lastTabKey)
        case .provider(let id):
            defaults.set("provider_\(id)", forKey: lastTabKey)
        }
        defaults.synchronize()
    }
    
    private func saveSettings() {
        switch defaultTab {
        case .overview:
            defaults.set("overview", forKey: defaultTabKey)
        case .provider(let id):
            defaults.set("provider_\(id)", forKey: defaultTabKey)
        }
        defaults.synchronize()
    }
    
    private func savePinnedProviders() {
        defaults.set(Array(pinnedProviders), forKey: pinnedProvidersKey)
        defaults.synchronize()
    }
    
    private func loadSettings() {
        if let lastTab = defaults.string(forKey: lastTabKey) {
            switch lastTab {
            case "overview":
                selectedTab = .overview
            case let provider where provider.hasPrefix("provider_"):
                let id = String(provider.dropFirst(9))
                selectedTab = .provider(id)
            default:
                selectedTab = .overview
            }
        }
        
        if let defaultTab = defaults.string(forKey: defaultTabKey) {
            switch defaultTab {
            case "overview":
                self.defaultTab = .overview
            case let provider where provider.hasPrefix("provider_"):
                let id = String(provider.dropFirst(9))
                self.defaultTab = .provider(id)
            default:
                self.defaultTab = .overview
            }
        }
        
        if let pinned = defaults.stringArray(forKey: pinnedProvidersKey) {
            pinnedProviders = Set(pinned)
        }
    }
}
