import SwiftUI

/// Compact provider card for overview tab
struct CompactProviderCard: View {
    @ObservedObject private var appSettings = AppSettings.shared
    let provider: UsageProvider
    let snapshot: UsageSnapshot?
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: provider.displayConfig.iconName)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                        
                        Text(provider.displayConfig.shortName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let percentage = primaryPercentage {
                            PercentageBadge(percentage: Int(percentage), color: Color(hex: provider.displayConfig.primaryColor))
                        }
                    }
                    
                    Spacer()
                    
                    statusIndicator
                }
                
                if snapshot != nil, let displayQuota = preferredQuota {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: min(displayQuota.computedPercentage / 100, 1.0))
                            .tint(progressColor)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        
                        HStack {
                            Text("\(Int(displayQuota.computedPercentage))% used")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            if let resetTime = displayQuota.resetDate {
                                Text("Resets \(formatResetTime(resetTime))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else if !provider.isAuthenticated {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isHovered ? Color(hex: provider.displayConfig.primaryColor).opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            NSCursor.pointingHand.push()
        }
    }
    
    private var preferredQuota: QuotaMetric? {
        guard let snapshot = snapshot else { return nil }
        let preferredId = AppSettings.shared.getPreferredQuotaId(for: provider.id)
        return snapshot.preferredQuota(quotaId: preferredId)
    }

    private var primaryPercentage: Double? {
        return preferredQuota?.computedPercentage
    }
    
    private var progressColor: Color {
        guard let percentage = primaryPercentage else { return .gray }
        
        if percentage < 70 {
            return .green
        } else if percentage < 90 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusIndicator: some View {
        Group {
            if case .authenticated = provider.authState {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            } else if case .failed = provider.authState {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
            }
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
}
