import SwiftUI

struct RarityBadgeView: View {
    let rarity: String

    private var badgeColor: Color {
        switch rarity.lowercased() {
        case "common":    return .secondary
        case "uncommon":  return .green
        case "rare":      return .blue
        case "epic":      return .purple
        case "legendary": return .orange
        case "mythic":    return .yellow
        default:          return .secondary
        }
    }

    var body: some View {
        Text(rarity)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.2), in: .capsule)
            .foregroundStyle(badgeColor)
    }
}
