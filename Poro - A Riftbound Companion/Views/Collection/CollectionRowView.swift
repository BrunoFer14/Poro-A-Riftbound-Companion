import SwiftUI

struct CollectionRowView: View {
    let entry: CollectionEntry
    let collectionStore: CollectionStore

    var body: some View {
        HStack(spacing: 12) {
            CardImageView(url: entry.card.media.imageUrl, width: 44, height: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.card.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    RarityBadgeView(rarity: entry.card.classification.rarity)
                    Text(entry.card.classification.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(entry.card.set.label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    collectionStore.decrement(entry.card)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                Text("\(entry.quantity)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 24, alignment: .center)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: entry.quantity)

                Button {
                    collectionStore.increment(entry.card)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
