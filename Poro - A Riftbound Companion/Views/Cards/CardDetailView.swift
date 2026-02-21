import SwiftUI

struct CardDetailView: View {
    let card: Card
    let collectionStore: CollectionStore

    var quantity: Int {
        collectionStore.quantity(for: card.id)
    }

    private var cardmarketURL: URL? {
        let slug = card.metadata.cleanName
            .replacingOccurrences(of: " ", with: "-")
        let path = "/en/Riftbound/Cards/\(slug)"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.cardmarket.com"
        components.path = path
        return components.url
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CardImageView(url: card.media.imageUrl, width: 260, height: 364)
                    .padding(.vertical, 20)
                    .shadow(radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name)
                                .font(.title2.bold())
                            if let supertype = card.classification.supertype {
                                Text(supertype)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        RarityBadgeView(rarity: card.classification.rarity)
                    }

                    // Attributes
                    if card.attributes.energy != nil || card.attributes.might != nil || card.attributes.power != nil {
                        HStack(spacing: 8) {
                            if let e = card.attributes.energy {
                                AttributeChip(label: "Energy", value: e, color: .yellow)
                            }
                            if let m = card.attributes.might {
                                AttributeChip(label: "Might", value: m, color: .red)
                            }
                            if let p = card.attributes.power {
                                AttributeChip(label: "Power", value: p, color: .blue)
                            }
                            Spacer()
                        }
                    }

                    Divider()

                    // Card info
                    VStack(spacing: 8) {
                        InfoRow(label: "Tipo", value: card.classification.type)
                        if !card.classification.domain.isEmpty {
                            InfoRow(label: "Domínio", value: card.classification.domain.joined(separator: ", "))
                        }
                        InfoRow(label: "Set", value: card.set.label)
                        InfoRow(label: "Nº Colecionador", value: "\(card.collectorNumber)")
                        InfoRow(label: "Artista", value: card.media.artist)
                    }

                    if !card.text.plain.isEmpty {
                        Divider()
                        RichCardText(text: card.text.plain)
                            .foregroundStyle(.secondary)
                    }

                    if !card.tags.isEmpty {
                        Divider()
                        Text(card.tags.map { "#\($0)" }.joined(separator: "  "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    // Cardmarket link
                    if let url = cardmarketURL {
                        Divider()
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "cart.fill")
                                    .font(.body)
                                Text("Ver no Cardmarket")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.tint.opacity(0.1), in: .rect(cornerRadius: 10))
                        }
                    }

                    Divider()

                    // Collection stepper
                    HStack {
                        Spacer()
                        Button {
                            collectionStore.decrement(card)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(quantity > 0 ? Color.red : Color.secondary.opacity(0.3))
                        }
                        .disabled(quantity == 0)

                        VStack(spacing: 2) {
                            Text("\(quantity)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(.snappy, value: quantity)
                            Text("na coleção")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 100)

                        Button {
                            collectionStore.increment(card)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.tint)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AttributeChip: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 64)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: .rect(cornerRadius: 8))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }
}
