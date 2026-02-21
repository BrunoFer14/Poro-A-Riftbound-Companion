import SwiftUI

struct DeckBuilderView: View {
    @State var deck: Deck
    let deckStore: DeckStore
    let collectionStore: CollectionStore
    var isNewDeck: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var showCardPicker = false
    @State private var isEditingName = false
    @State private var selectedCard: Card?
    @FocusState private var nameFocused: Bool

    private var energyCurve: [(Int, Int)] {
        var curve: [Int: Int] = [:]
        for entry in deck.entries {
            let energy = entry.card.attributes.energy ?? 0
            curve[energy, default: 0] += entry.quantity
        }
        return curve.sorted { $0.key < $1.key }
    }

    private var sortedEntries: [DeckEntry] {
        deck.entries.sorted { ($0.card.attributes.energy ?? 0) < ($1.card.attributes.energy ?? 0) }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Legend header
                HStack(spacing: 12) {
                    CardImageView(url: deck.legend.media.imageUrl, width: 60, height: 84)

                    VStack(alignment: .leading, spacing: 6) {
                        if isEditingName {
                            TextField("Nome do deck", text: $deck.name)
                                .font(.headline)
                                .focused($nameFocused)
                                .onSubmit { isEditingName = false }
                        } else {
                            Button {
                                isEditingName = true
                                nameFocused = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text(deck.name)
                                        .font(.headline)
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }

                        Text(deck.legend.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            ForEach(deck.domains, id: \.self) { domain in
                                DomainBadge(domain: domain)
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("\(deck.totalCards)")
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(deck.isComplete ? .green : .primary)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: deck.totalCards)
                        Text("/40")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

                // Cards in deck
                if deck.entries.isEmpty {
                    ContentUnavailableView(
                        "Sem cartas",
                        systemImage: "plus.rectangle.on.rectangle",
                        description: Text("Toca em + para adicionar cartas ao deck.")
                    )
                    .padding(.top, 20)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(sortedEntries) { entry in
                            let ownedQty = collectionStore.quantity(for: entry.card.id)
                            let canAdd = entry.quantity < min(3, ownedQty) && deck.totalCards < 40

                            DeckBuilderGridCell(
                                entry: entry,
                                canAdd: canAdd
                            ) {
                                deck.addCard(entry.card, ownedQuantity: ownedQty)
                            } onRemove: {
                                deck.removeCard(entry.card)
                            } onTap: {
                                selectedCard = entry.card
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Construir Deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCardPicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    saveDeck()
                }
            }
        }
        .sheet(isPresented: $showCardPicker) {
            DeckCardPickerView(
                deck: $deck,
                collectionStore: collectionStore
            )
            .presentationDetents([.large])
        }
        .navigationDestination(item: $selectedCard) { card in
            CardDetailView(card: card, collectionStore: collectionStore)
        }
    }

    private func saveDeck() {
        if isNewDeck {
            deckStore.addDeck(deck)
        } else {
            deckStore.updateDeck(deck)
        }
        dismiss()
    }
}

private struct DeckBuilderGridCell: View {
    let entry: DeckEntry
    let canAdd: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onTap) {
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
            }
            .buttonStyle(.plain)

            Text(entry.card.name)
                .font(.caption2)
                .lineLimit(1)

            HStack(spacing: 12) {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .foregroundStyle(canAdd ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.3)))
            }
        }
    }
}
