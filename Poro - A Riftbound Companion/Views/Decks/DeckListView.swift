import SwiftUI

struct DeckListView: View {
    let collectionStore: CollectionStore
    let deckStore: DeckStore

    @State private var showLegendPicker = false
    @State private var selectedDeck: Deck?

    var body: some View {
        NavigationStack {
            Group {
                if deckStore.decks.isEmpty {
                    ContentUnavailableView(
                        "Sem decks",
                        systemImage: "square.3.layers.3d",
                        description: Text("Cria o teu primeiro deck para começar.")
                    )
                } else {
                    List {
                        ForEach(deckStore.decks) { deck in
                            Button {
                                selectedDeck = deck
                            } label: {
                                DeckRowView(deck: deck)
                            }
                            .tint(.primary)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                deckStore.deleteDeck(id: deckStore.decks[index].id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Decks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLegendPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showLegendPicker) {
                LegendPickerView(
                    collectionStore: collectionStore,
                    deckStore: deckStore
                )
            }
            .fullScreenCover(item: $selectedDeck) { deck in
                NavigationStack {
                    DeckDetailView(deck: deck, deckStore: deckStore, collectionStore: collectionStore)
                }
            }
        }
    }
}

private struct DeckRowView: View {
    let deck: Deck

    var body: some View {
        HStack(spacing: 12) {
            CardImageView(url: deck.legend.media.imageUrl, width: 52, height: 73)

            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(deck.legend.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    ForEach(deck.domains, id: \.self) { domain in
                        DomainBadge(domain: domain)
                    }
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(deck.totalCards)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(deck.isComplete ? .green : .secondary)
                Text("/40")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DomainBadge: View {
    let domain: String

    var body: some View {
        Text(domain)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch domain.lowercased() {
        case "body": return .orange
        case "calm": return .green
        case "chaos": return .purple
        case "fury": return .red
        case "mind": return .blue
        case "order": return .yellow
        default: return .secondary
        }
    }
}
