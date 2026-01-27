import SwiftUI

/// Horizontal tab bar with provider icons and overview
struct TabBar: View {
    @ObservedObject var tabState: TabState
    let providers: [UsageProvider]
    let snapshots: [String: UsageSnapshot]
    
    private let maxVisibleTabs = 99
    
    var body: some View {
        HStack(spacing: 4) {
            TabButton(
                icon: "square.grid.2x2",
                title: "Overview",
                isSelected: tabState.selectedTab.isOverview,
                action: { tabState.selectOverview() }
            )
            .frame(maxWidth: .infinity)

            ForEach(visibleProviders, id: \.id) { provider in
                TabButton(
                    icon: provider.displayConfig.iconName,
                    title: provider.displayConfig.shortName,
                    isSelected: tabState.selectedTab.providerId == provider.id,
                    percentage: snapshotPercentage(for: provider.id),
                    color: Color(hex: provider.displayConfig.primaryColor),
                    action: { tabState.selectProvider(provider.id) }
                )
                .frame(maxWidth: .infinity)
            }

            if hasMoreProviders {
                MoreButton(
                    hiddenProviders: hiddenProviders,
                    tabState: tabState
                )
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    private var visibleProviders: [UsageProvider] {
        return sortedProviders.prefix(maxVisibleTabs).reversed().reversed()
    }
    
    private var hiddenProviders: [UsageProvider] {
        return Array(sortedProviders.dropFirst(maxVisibleTabs))
    }
    
    private var hasMoreProviders: Bool {
        return sortedProviders.count > maxVisibleTabs
    }
    
    private var sortedProviders: [UsageProvider] {
        return providers.sorted { provider1, provider2 in
            let snap1 = snapshots[provider1.id]?.maxUsagePercentage ?? 0
            let snap2 = snapshots[provider2.id]?.maxUsagePercentage ?? 0
            return snap1 > snap2
        }
    }
    
    private func snapshotPercentage(for providerId: String) -> Int? {
        guard let snapshot = snapshots[providerId] else { return nil }
        return Int(snapshot.maxUsagePercentage)
    }
}

/// More button dropdown for additional providers
struct MoreButton: View {
    let hiddenProviders: [UsageProvider]
    @ObservedObject var tabState: TabState
    @State private var isShowingDropdown = false
    
    var body: some View {
        Menu {
            ForEach(hiddenProviders, id: \.id) { provider in
                Button(action: { tabState.selectProvider(provider.id) }) {
                    HStack {
                        Image(systemName: provider.displayConfig.iconName)
                            .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                        Text(provider.displayConfig.shortName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("More")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }
}
