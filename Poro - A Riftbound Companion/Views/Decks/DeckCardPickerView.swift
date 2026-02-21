import SwiftUI

struct DeckCardPickerView: View {
    @Binding var deck: Deck
    let collectionStore: CollectionStore

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCard: Card?
    @State private var selectedEnergyCosts: Set<Int> = []

    private var eligibleCards: [Card] {
        let domainSet = Set(deck.domains)
        return collectionStore.entries
            .map(\.card)
            .filter { card in
                guard card.classification.type != "Legend" else { return false }
                return !Set(card.classification.domain).isDisjoint(with: domainSet)
            }
            .sorted { ($0.attributes.energy ?? 0) < ($1.attributes.energy ?? 0) }
    }

    private var filteredCards: [Card] {
        var result = eligibleCards
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if !selectedEnergyCosts.isEmpty {
            result = result.filter { card in
                guard let energy = card.attributes.energy else { return false }
                return selectedEnergyCosts.contains(energy)
            }
        }
        return result
    }

    private var availableEnergyCosts: [Int] {
        Array(Set(eligibleCards.compactMap { $0.attributes.energy })).sorted()
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Energy cost filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableEnergyCosts, id: \.self) { cost in
                                let isSelected = selectedEnergyCosts.contains(cost)
                                Button {
                                    if isSelected {
                                        selectedEnergyCosts.remove(cost)
                                    } else {
                                        selectedEnergyCosts.insert(cost)
                                    }
                                } label: {
                                    Text("\(cost)")
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: .capsule)
                                        .foregroundStyle(isSelected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Cards grid
                    if filteredCards.isEmpty {
                        if searchText.isEmpty && selectedEnergyCosts.isEmpty {
                            ContentUnavailableView(
                                "Sem cartas disponíveis",
                                systemImage: "rectangle.stack.badge.minus",
                                description: Text("Não tens cartas dos domínios \(deck.domains.joined(separator: " e ")) na tua coleção.")
                            )
                            .padding(.top, 40)
                        } else {
                            ContentUnavailableView(
                                "Sem resultados",
                                systemImage: "magnifyingglass",
                                description: Text("Nenhuma carta corresponde à pesquisa ou filtros.")
                            )
                            .padding(.top, 40)
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredCards) { card in
                                let deckQty = deck.quantity(for: card.id)
                                let ownedQty = collectionStore.quantity(for: card.id)
                                let limit = min(3, ownedQty)
                                let canAdd = deckQty < limit && deck.totalCards < 40

                                PickerGridCell(
                                    card: card,
                                    quantityInDeck: deckQty,
                                    ownedQuantity: ownedQty,
                                    canAdd: canAdd
                                ) {
                                    deck.addCard(card, ownedQuantity: ownedQty)
                                } onRemove: {
                                    deck.removeCard(card)
                                } onTap: {
                                    selectedCard = card
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Adicionar Cartas")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Pesquisar cartas...")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(deck.totalCards)/40")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(deck.isComplete ? .green : .secondary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: deck.totalCards)
                }
            }
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card, collectionStore: collectionStore)
            }
        }
    }
}

private struct PickerGridCell: View {
    let card: Card
    let quantityInDeck: Int
    let ownedQuantity: Int
    let canAdd: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onTap) {
                CardImageView(url: card.media.imageUrl, width: 100, height: 140)
                    .overlay(alignment: .topTrailing) {
                        Text("×\(ownedQuantity)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.secondary, in: .capsule)
                            .padding(4)
                    }
            }
            .buttonStyle(.plain)

            Text(card.name)
                .font(.caption2)
                .lineLimit(1)

            HStack(spacing: 8) {
                if quantityInDeck > 0 {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    Text("\(quantityInDeck)")
                        .font(.subheadline.bold().monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(.snappy, value: quantityInDeck)
                }

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
