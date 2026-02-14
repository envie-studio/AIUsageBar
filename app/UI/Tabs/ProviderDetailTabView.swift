import SwiftUI

/// Provider detail tab showing full usage information
struct ProviderDetailTabView: View {
    let provider: UsageProvider
    let snapshot: UsageSnapshot?
    let onConfigure: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            header

            if let snapshot = snapshot {
                quotasView

                if hasAdditionalInfo {
                    additionalInfo
                }
            } else if !provider.isAuthenticated {
                notConfiguredView
            } else {
                loadingView
            }
        }
        .padding()
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: provider.displayConfig.iconName)
                    .font(.title2)
                    .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.headline)
                    
                    if let snapshot = snapshot {
                        Text("\(Int(snapshot.maxUsagePercentage))% overall usage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if provider.isAuthenticated {
                Button(action: onConfigure) {
                    Image(systemName: "gear")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Configure \(provider.name)")
            }
        }
        .padding(.bottom, 4)
    }
    
    private var quotasView: some View {
        VStack(spacing: 12) {
            ForEach(Array(quotasByPriority), id: \.id) { quota in
                DetailedQuotaRowView(quota: quota, providerColor: Color(hex: provider.displayConfig.primaryColor))
            }
        }
    }
    
    private var quotasByPriority: [QuotaMetric] {
        guard let snapshot = snapshot else { return [] }

        let sessionQuota = snapshot.quotas.first { $0.name.contains("Session") || $0.name.contains("5 hour") }
        let dailyQuota = snapshot.quotas.first { $0.name.contains("Daily") }
        let weeklyQuota = snapshot.quotas.first { $0.name.contains("Weekly") }
        let otherQuotas = snapshot.quotas.filter { quota in
            let sessionQuotaId = sessionQuota?.id
            let dailyQuotaId = dailyQuota?.id
            let weeklyQuotaId = weeklyQuota?.id
            return quota.id != sessionQuotaId && quota.id != dailyQuotaId && quota.id != weeklyQuotaId
        }

        var result: [QuotaMetric] = []
        if let session = sessionQuota { result.append(session) }
        if let daily = dailyQuota { result.append(daily) }
        if let weekly = weeklyQuota { result.append(weekly) }
        result.append(contentsOf: otherQuotas)

        return result
    }
    
    private var hasAdditionalInfo: Bool {
        guard let snapshot = snapshot else { return false }
        return snapshot.inputTokens != nil || snapshot.outputTokens != nil || snapshot.totalCost != nil
    }
    
    private var additionalInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                if let input = snapshot?.inputTokens {
                    InfoItem(label: "Input Tokens", value: formatNumber(input))
                }
                
                if let output = snapshot?.outputTokens {
                    InfoItem(label: "Output Tokens", value: formatNumber(output))
                }
                
                if let cost = snapshot?.totalCost {
                    Divider()
                        .frame(height: 30)
                    
                    InfoItem(label: "Total Cost", value: String(format: "$%.2f", Double(truncating: cost as NSNumber)))
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var notConfiguredView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            VStack(spacing: 4) {
                Text("Not Configured")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Configure your credentials to track usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Configure Now") {
                onConfigure()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading usage data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return "\(value)"
        }
    }
}

/// Detailed quota row with full information
struct DetailedQuotaRowView: View {
    let quota: QuotaMetric
    let providerColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(quota.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let resetDate = quota.resetDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Resets \(formatResetTime(resetDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            ProgressView(value: min(quota.computedPercentage / 100, 1.0))
                .tint(progressColor)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            
            HStack {
                HStack(spacing: 8) {
                    Text("\(Int(quota.computedPercentage))% used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if quota.computedPercentage >= 80 {
                        Text("⚠️")
                            .font(.caption2)
                    }
                }
                
                Spacer()
                
                if let used = quota.used, let limit = quota.limit {
                    Text("\(formatNumber(used))/\(formatNumber(limit)) \(quota.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var progressColor: Color {
        if quota.computedPercentage < 70 {
            return .green
        } else if quota.computedPercentage < 90 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatResetTime(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "at \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return "on \(formatter.string(from: date))"
        }
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

/// Small info item for additional details
struct InfoItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }
}
