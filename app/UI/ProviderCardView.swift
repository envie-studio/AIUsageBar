import SwiftUI

/// Card view for displaying a single provider's usage
struct ProviderCardView: View {
    let provider: UsageProvider
    let snapshot: UsageSnapshot?
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                // Provider icon and name
                HStack(spacing: 6) {
                    Image(systemName: provider.displayConfig.iconName)
                        .foregroundColor(Color(hex: provider.displayConfig.primaryColor))
                        .font(.system(size: 14))

                    Text(provider.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                // Status indicator
                if provider.isAuthenticated {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                }

                // Expand/collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            if isExpanded {
                if let snapshot = snapshot {
                    // Show quotas
                    ForEach(snapshot.quotas) { quota in
                        QuotaRowView(quota: quota)
                    }
                } else if !provider.isAuthenticated {
                    // Not authenticated
                    Text("Not configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Loading or no data
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Row view for a single quota metric
struct QuotaRowView: View {
    let quota: QuotaMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(quota.name)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let resetDate = quota.resetDate {
                    Text("Resets \(formatResetTime(resetDate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            ProgressView(value: min(quota.computedPercentage / 100, 1.0))
                .tint(colorForPercentage(quota.computedPercentage / 100))

            HStack {
                Text("\(Int(quota.computedPercentage))% used")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                if let used = quota.used, let limit = quota.limit {
                    Text("\(formatNumber(used))/\(formatNumber(limit)) \(quota.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func formatResetTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "at \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "d MMM 'at' h:mm a"
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

    private func colorForPercentage(_ percentage: Double) -> Color {
        if percentage < 0.7 {
            return .green
        } else if percentage < 0.9 {
            return .orange
        } else {
            return .red
        }
    }
}

/// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
