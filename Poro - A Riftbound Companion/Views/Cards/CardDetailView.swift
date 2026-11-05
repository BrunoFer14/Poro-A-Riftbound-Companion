import SwiftUI
import FirebaseAuth

struct CardDetailView: View {
    let card: Card
    let collectionStore: CollectionStore
    var authService: AuthService? = nil
    var cardCache: CardCache? = nil

    @State private var showSellSheet = false
    @State private var showBuySheet = false
    @State private var sellViewModel = MarketplaceViewModel()

    var quantity: Int {
        collectionStore.quantity(for: card.id)
    }

    var foilQty: Int {
        collectionStore.foilQuantity(for: card.id)
    }

    var promoQty: Int {
        collectionStore.promoQuantity(for: card.id)
    }

    private var otherVersions: [Card] {
        cardCache?.otherVersions(of: card) ?? []
    }

    private var cardmarketURL: URL? {
        let slug = (card.metadata.cleanName ?? card.name)
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

                    if let flavour = card.text.flavour, !flavour.isEmpty {
                        Text(flavour)
                            .font(.subheadline.italic())
                            .foregroundStyle(.tertiary)
                            .padding(.top, card.text.plain.isEmpty ? 0 : 4)
                    }

                    if !card.tags.isEmpty {
                        Divider()
                        Text(card.tags.map { "#\($0)" }.joined(separator: "  "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    // Other versions
                    if !otherVersions.isEmpty {
                        Divider()
                        NavigationLink(value: CardVersionsDestination(card: card)) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.stack.3d.up")
                                    .font(.body)
                                Text("Outras versões (\(otherVersions.count))")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.tint.opacity(0.1), in: .rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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

                    // Marketplace actions (only when logged in)
                    if let auth = authService, auth.isLoggedIn {
                        Divider()
                        HStack(spacing: 12) {
                            Button {
                                showBuySheet = true
                            } label: {
                                Label("Comprar", systemImage: "magnifyingglass")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.accentColor.opacity(0.1), in: .rect(cornerRadius: 10))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)

                            Button {
                                showSellSheet = true
                            } label: {
                                Label("Vender", systemImage: "tag")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.green.opacity(0.1), in: .rect(cornerRadius: 10))
                                    .foregroundStyle(Color.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    // Collection stepper — normal
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

                    // Collection stepper — foil
                    HStack {
                        Spacer()
                        Button {
                            collectionStore.decrementFoil(card)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(foilQty > 0 ? Color.red : Color.secondary.opacity(0.3))
                        }
                        .disabled(foilQty == 0)

                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text("✦")
                                    .font(.title3)
                                    .foregroundStyle(.purple)
                                Text("\(foilQty)")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
                                    .animation(.snappy, value: foilQty)
                            }
                            Text("foil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 100)

                        Button {
                            collectionStore.incrementFoil(card)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.purple)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    // Collection stepper — promo
                    HStack {
                        Spacer()
                        Button {
                            collectionStore.decrementPromo(card)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(promoQty > 0 ? Color.red : Color.secondary.opacity(0.3))
                        }
                        .disabled(promoQty == 0)

                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text("P")
                                    .font(.title3.bold())
                                    .foregroundStyle(.orange)
                                Text("\(promoQty)")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
                                    .animation(.snappy, value: promoQty)
                            }
                            Text("promo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 100)

                        Button {
                            collectionStore.incrementPromo(card)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CardVersionsDestination.self) { dest in
            CardVersionsView(
                card: dest.card,
                collectionStore: collectionStore,
                cardCache: cardCache,
                authService: authService
            )
        }
        .sheet(isPresented: $showSellSheet) {
            if let auth = authService {
                CreateListingView(
                    authService: auth,
                    cardCache: cardCache ?? CardCache(),
                    viewModel: sellViewModel,
                    preselectedCard: card
                )
            }
        }
        .sheet(isPresented: $showBuySheet) {
            CardListingsSheet(cardName: card.name, authService: authService)
        }
    }
}

// MARK: - Navigation Value

struct CardVersionsDestination: Hashable {
    let card: Card
}

// MARK: - Card Versions View

struct CardVersionsView: View {
    let card: Card
    let collectionStore: CollectionStore
    let cardCache: CardCache?
    let authService: AuthService?

    private var versions: [Card] {
        cardCache?.otherVersions(of: card) ?? []
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(versions) { version in
                    NavigationLink(value: version) {
                        VStack(spacing: 6) {
                            CardImageView(url: version.media.imageUrl, width: 100, height: 140)
                                .overlay(alignment: .topTrailing) {
                                    let qty = collectionStore.totalQuantity(for: version.id)
                                    if qty > 0 {
                                        Text("×\(qty)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(.secondary, in: .capsule)
                                            .padding(4)
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    let foil = collectionStore.foilQuantity(for: version.id)
                                    if foil > 0 {
                                        Text("✦\(foil)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                                    .opacity(0.85),
                                                in: .capsule
                                            )
                                            .padding(4)
                                    }
                                }
                                .opacity(collectionStore.totalQuantity(for: version.id) > 0 ? 1.0 : 0.4)

                            VStack(spacing: 2) {
                                Text(version.name)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(collectionStore.totalQuantity(for: version.id) > 0 ? .primary : .secondary)
                                Text(version.set.label)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Outras versões")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Card.self) { card in
            CardDetailView(card: card, collectionStore: collectionStore, authService: authService, cardCache: cardCache)
        }
    }
}

// MARK: - Private Views

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
