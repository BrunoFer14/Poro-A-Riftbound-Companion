import SwiftUI

struct DeckDetailView: View {
    let deckId: UUID
    let deckStore: DeckStore
    let collectionStore: CollectionStore

    @Environment(\.dismiss) private var dismiss
    @State private var showBuilder = false
    @State private var showCodeCopied = false
    @State private var showDeleteConfirmation = false

    private var deck: Deck? {
        deckStore.decks.first { $0.id == deckId }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    private struct CardTypeSection: Identifiable {
        let type: String
        let label: String
        let entries: [DeckEntry]
        var id: String { type }
        var totalCards: Int { entries.reduce(0) { $0 + $1.quantity } }
    }

    private var groupedSections: [CardTypeSection] {
        let entries = deck?.entries ?? []
        let typeOrder = ["Unit", "Gear", "Spell"]
        let labels = ["Unit": "Units", "Gear": "Gear", "Spell": "Spells"]
        let grouped = Dictionary(grouping: entries) { $0.card.classification.type }

        return typeOrder.compactMap { type in
            guard let sectionEntries = grouped[type], !sectionEntries.isEmpty else { return nil }
            let sorted = sectionEntries.sorted { ($0.card.attributes.energy ?? 0) < ($1.card.attributes.energy ?? 0) }
            return CardTypeSection(type: type, label: labels[type] ?? type, entries: sorted)
        }
    }

    private var energyCurve: [(Int, Int)] {
        var curve: [Int: Int] = [:]
        for entry in (deck?.entries ?? []) {
            let energy = entry.card.attributes.energy ?? 0
            curve[energy, default: 0] += entry.quantity
        }
        return curve.sorted { $0.key < $1.key }
    }

    var body: some View {
        if let deck {
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

                // Runes
                if deck.totalRunes > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Runes")
                                .font(.headline)
                            Text("(\(deck.totalRunes)/12)")
                                .font(.subheadline)
                                .foregroundStyle(deck.hasAllRunes ? .green : .orange)
                        }

                        HStack(spacing: 12) {
                            ForEach(deck.domains, id: \.self) { domain in
                                if let count = deck.runes[domain], count > 0 {
                                    HStack(spacing: 4) {
                                        DomainBadge(domain: domain)
                                        Text("×\(count)")
                                            .font(.subheadline.bold().monospacedDigit())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Battlefields
                if !deck.battlefields.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Battlefields (\(deck.battlefields.count)/3)")
                            .font(.headline)

                        HStack(spacing: 8) {
                            ForEach(deck.battlefields) { battlefield in
                                VStack(spacing: 4) {
                                    CardImageView(url: battlefield.media.imageUrl, width: 80, height: 112)
                                    Text(battlefield.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Cards grouped by type
                ForEach(groupedSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(section.label) (\(section.totalCards))")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(section.entries) { entry in
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
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }

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
        .confirmationDialog("Apagar este deck?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) {
                deckStore.deleteDeck(id: deckId)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação não pode ser revertida.")
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
        } else {
            ContentUnavailableView("Deck não encontrado", systemImage: "exclamationmark.triangle")
        }
    }
}
