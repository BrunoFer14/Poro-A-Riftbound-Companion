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

            VStack(spacing: 6) {
                // Normal quantity
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

                // Foil quantity
                HStack(spacing: 10) {
                    Button {
                        collectionStore.decrementFoil(entry.card)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 2) {
                        Text("✦")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text("\(entry.foilQuantity)")
                            .font(.subheadline.monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.snappy, value: entry.foilQuantity)
                    }
                    .frame(minWidth: 24, alignment: .center)

                    Button {
                        collectionStore.incrementFoil(entry.card)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                }

                // Promo quantity
                HStack(spacing: 10) {
                    Button {
                        collectionStore.decrementPromo(entry.card)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 2) {
                        Text("P")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                        Text("\(entry.promoQuantity)")
                            .font(.subheadline.monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.snappy, value: entry.promoQuantity)
                    }
                    .frame(minWidth: 24, alignment: .center)

                    Button {
                        collectionStore.incrementPromo(entry.card)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
