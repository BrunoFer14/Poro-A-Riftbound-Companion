import SwiftUI

struct LegendPickerView: View {
    let collectionStore: CollectionStore
    let deckStore: DeckStore

    @Environment(\.dismiss) private var dismiss
    @State private var createdDeck: Deck?

    private var legends: [Card] {
        collectionStore.entries
            .map(\.card)
            .filter { $0.classification.type == "Legend" }
            .sorted { $0.name < $1.name }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if legends.isEmpty {
                    ContentUnavailableView(
                        "Sem Legends",
                        systemImage: "crown",
                        description: Text("Adiciona Legends à tua coleção primeiro.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(legends) { legend in
                                Button {
                                    createDeck(with: legend)
                                } label: {
                                    LegendCell(legend: legend)
                                }
                                .tint(.primary)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Escolher Legend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .fullScreenCover(item: $createdDeck) { deck in
                NavigationStack {
                    DeckBuilderView(
                        deck: deck,
                        deckStore: deckStore,
                        collectionStore: collectionStore,
                        isNewDeck: true
                    )
                }
            }
        }
    }

    private func createDeck(with legend: Card) {
        let deck = Deck(
            id: UUID(),
            name: legend.name,
            legend: legend,
            entries: [],
            createdAt: .now
        )
        createdDeck = deck
    }
}

private struct LegendCell: View {
    let legend: Card

    var body: some View {
        VStack(spacing: 8) {
            CardImageView(url: legend.media.imageUrl, width: 140, height: 196)
                .shadow(radius: 4, y: 2)

            VStack(spacing: 4) {
                Text(legend.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 4) {
                    ForEach(legend.classification.domain, id: \.self) { domain in
                        DomainBadge(domain: domain)
                    }
                }
            }
        }
    }
}
