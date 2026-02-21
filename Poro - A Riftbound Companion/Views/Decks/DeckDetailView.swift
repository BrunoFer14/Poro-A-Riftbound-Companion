import SwiftUI

struct DeckDetailView: View {
    let deck: Deck
    let deckStore: DeckStore
    let collectionStore: CollectionStore

    @Environment(\.dismiss) private var dismiss
    @State private var showBuilder = false
    @State private var showCodeCopied = false

    private var sortedEntries: [DeckEntry] {
        deck.entries.sorted { ($0.card.attributes.energy ?? 0) < ($1.card.attributes.energy ?? 0) }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    private var energyCurve: [(Int, Int)] {
        var curve: [Int: Int] = [:]
        for entry in deck.entries {
            let energy = entry.card.attributes.energy ?? 0
            curve[energy, default: 0] += entry.quantity
        }
        return curve.sorted { $0.key < $1.key }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Legend section
                HStack(spacing: 14) {
                    CardImageView(url: deck.legend.media.imageUrl, width: 70, height: 98)
                        .shadow(radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(deck.name)
                            .font(.title3.bold())
                        Text(deck.legend.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            ForEach(deck.domains, id: \.self) { domain in
                                DomainBadge(domain: domain)
                            }
                        }

                        Text("\(deck.totalCards)/40 cartas")
                            .font(.caption)
                            .foregroundStyle(deck.isComplete ? .green : .orange)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                // Rune curve
                if !energyCurve.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rune Curve")
                            .font(.headline)
                        RuneCurveChart(curve: energyCurve)
                    }
                    .padding(.horizontal)
                }

                // Cards grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(sortedEntries) { entry in
                        VStack(spacing: 4) {
                            CardImageView(url: entry.card.media.imageUrl, width: 100, height: 140)
                                .overlay(alignment: .topTrailing) {
                                    Text("×\(entry.quantity)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.tint, in: .capsule)
                                        .padding(4)
                                }

                            Text(entry.card.name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        let code = DeckCodec.encode(deck: deck)
                        UIPasteboard.general.string = code
                        showCodeCopied = true
                    } label: {
                        Image(systemName: "square.on.square")
                    }

                    Button {
                        showBuilder = true
                    } label: {
                        Text("Editar")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showBuilder) {
            NavigationStack {
                DeckBuilderView(
                    deck: deck,
                    deckStore: deckStore,
                    collectionStore: collectionStore
                )
            }
        }
        .overlay(alignment: .bottom) {
            if showCodeCopied {
                Text("Código copiado!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.green, in: .capsule)
                    .shadow(radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { showCodeCopied = false }
                        }
                    }
            }
        }
        .animation(.snappy, value: showCodeCopied)
    }
}
