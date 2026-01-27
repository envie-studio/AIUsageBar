import SwiftUI

/// Individual tab button with icon, title, and optional percentage badge
struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let percentage: Int?
    let color: Color?
    let action: () -> Void
    
    init(icon: String, title: String, isSelected: Bool, percentage: Int? = nil, color: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.percentage = percentage
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(tabColor)
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    if let pct = percentage {
                        PercentageBadge(percentage: pct, color: color)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color(NSColor.controlAccentColor).opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? Color(NSColor.controlAccentColor).opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
                
                if isSelected {
                    Rectangle()
                        .fill(Color(NSColor.controlAccentColor))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            NSCursor.pointingHand.push()
        }
    }
    
    private var tabColor: Color {
        if let color = color {
            return color
        }
        return isSelected ? Color(NSColor.controlAccentColor) : .secondary
    }
}

/// Percentage badge for tab buttons
struct PercentageBadge: View {
    let percentage: Int
    let color: Color?
    
    var body: some View {
        Text("\(percentage)%")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor)
            .cornerRadius(4)
    }
    
    private var badgeColor: Color {
        if let color = color {
            return color
        }
        
        if percentage < 70 {
            return Color(red: 0.13, green: 0.77, blue: 0.37)
        } else if percentage < 90 {
            return Color(red: 1.0, green: 0.8, blue: 0.0)
        } else {
            return Color(red: 1.0, green: 0.23, blue: 0.19)
        }
    }
}
