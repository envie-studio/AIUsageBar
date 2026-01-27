import SwiftUI

/// Overview tab showing compact summary of all providers
struct OverviewTabView: View {
    @ObservedObject var usageManager: MultiProviderUsageManager
    let onProviderTap: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if hasEnabledProviders {
                statusBanner
                
                providerGrid
                
                quickStats
            } else {
                emptyState
            }
        }
        .padding()
    }
    
    private var hasEnabledProviders: Bool {
        return !enabledProviders.isEmpty
    }
    
    private var enabledProviders: [UsageProvider] {
        return usageManager.providers.values
            .filter { $0.isAuthenticated && AppSettings.shared.isProviderEnabled($0.id) }
            .sorted { provider1, provider2 in
                let snap1 = usageManager.snapshots[provider1.id]?.maxUsagePercentage ?? 0
                let snap2 = usageManager.snapshots[provider2.id]?.maxUsagePercentage ?? 0
                return snap1 > snap2
            }
    }
    
    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusIcon: String {
        if hasHighUsage {
            return "exclamationmark.triangle.fill"
        } else if hasErrors {
            return "xmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        if hasHighUsage {
            return .orange
        } else if hasErrors {
            return .red
        } else {
            return .green
        }
    }
    
    private var statusTitle: String {
        if hasHighUsage {
            return "High Usage"
        } else if hasErrors {
            return "Attention Needed"
        } else {
            return "All Systems Good"
        }
    }
    
    private var statusMessage: String {
        if hasHighUsage {
            return "One or more providers are above 80% usage"
        } else if hasErrors {
            return "Some providers need attention"
        } else {
            return "\(enabledProviders.count) provider\(enabledProviders.count == 1 ? "" : "s") connected"
        }
    }
    
    private var hasHighUsage: Bool {
        return enabledProviders.contains { provider in
            guard let snapshot = usageManager.snapshots[provider.id] else { return false }
            return snapshot.maxUsagePercentage >= 80
        }
    }
    
    private var hasErrors: Bool {
        return usageManager.providers.values.contains { provider in
            if case .failed = provider.authState { return true }
            return false
        }
    }
    
    private var providerGrid: some View {
        VStack(spacing: 12) {
            ForEach(enabledProviders, id: \.id) { provider in
                CompactProviderCard(
                    provider: provider,
                    snapshot: usageManager.snapshots[provider.id],
                    onTap: { onProviderTap(provider.id) }
                )
            }
        }
    }
    
    private var quickStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Stats")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                StatItem(
                    icon: "chart.bar.fill",
                    label: "Total Providers",
                    value: "\(enabledProviders.count)"
                )
                
                Divider()
                    .frame(height: 30)
                
                if let highest = highestUsageProvider {
                    StatItem(
                        icon: "arrow.up.circle.fill",
                        label: "Highest Usage",
                        value: "\(Int(highest.value))%",
                        color: highest.color
                    )
                }
                
                if let nextReset = nextResetTime {
                    Divider()
                        .frame(height: 30)
                    
                    StatItem(
                        icon: "clock.fill",
                        label: "Next Reset",
                        value: nextReset
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var highestUsageProvider: (value: Double, color: Color)? {
        guard let maxSnapshot = enabledProviders
            .compactMap({ usageManager.snapshots[$0.id] })
            .max(by: { $0.maxUsagePercentage < $1.maxUsagePercentage }) else {
            return nil
        }
        
        let percentage = maxSnapshot.maxUsagePercentage
        let color: Color
        if percentage < 70 {
            color = .green
        } else if percentage < 90 {
            color = .orange
        } else {
            color = .red
        }
        
        return (percentage, color)
    }
    
    private var nextResetTime: String? {
        var nearestDate: Date?
        
        for provider in enabledProviders {
            guard let snapshot = usageManager.snapshots[provider.id] else { continue }
            
            for quota in snapshot.quotas {
                guard let resetDate = quota.resetDate else { continue }
                
                if nearestDate == nil || resetDate < nearestDate! {
                    nearestDate = resetDate
                }
            }
        }
        
        guard let date = nearestDate else { return nil }
        
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "Soon" }
        
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            let days = hours / 24
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Providers Configured")
                    .font(.headline)
                
                Text("Add your first AI provider to start tracking usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Quick stat item
struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .secondary
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
}
