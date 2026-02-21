import SwiftUI

struct CardRowView: View {
    let card: Card
    let quantity: Int
    var onAdd: (() -> Void)?
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            CardImageView(url: card.media.imageUrl, width: 48, height: 67)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    RarityBadgeView(rarity: card.classification.rarity)
                    Text(card.classification.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(card.set.label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if let onRemove, quantity > 0 {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            if quantity > 0 {
                Text("×\(quantity)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.12), in: .capsule)
            }

            if let onAdd {
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
