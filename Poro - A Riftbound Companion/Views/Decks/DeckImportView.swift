import SwiftUI

struct DeckImportView: View {
    let collectionStore: CollectionStore
    let deckStore: DeckStore
    let cardCache: CardCache

    @Environment(\.dismiss) private var dismiss
    @State private var codeText = ""
    @State private var decoded: DecodedDeck?
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Código do Deck") {
                    TextField("Cola o código aqui...", text: $codeText, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                    Button("Importar") {
                        importDeck()
                    }
                    .disabled(codeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("A carregar cartas...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if let decoded {
                    importPreview(decoded)
                }
            }
            .navigationTitle("Importar Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func importPreview(_ decoded: DecodedDeck) -> some View {
        let resolvedLegend = resolved(forCode: decoded.chosenChampion)
        let resolvedCards = decoded.mainDeck.map { card in
            (card, findCard(code: card.cardCode))
        }
        let foundCards = resolvedCards.compactMap { entry -> (Card, Int)? in
            guard let card = entry.1 else { return nil }
            return (card, entry.0.count)
        }
        let missingCodes = resolvedCards.filter { $0.1 == nil }.map { $0.0 }

        if let legend = resolvedLegend {
            Section("Legenda") {
                HStack(spacing: 12) {
                    CardImageView(url: legend.media.imageUrl, width: 50, height: 70)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(legend.name)
                            .font(.headline)
                        HStack(spacing: 4) {
                            ForEach(legend.classification.domain, id: \.self) { domain in
                                DomainBadge(domain: domain)
                            }
                        }
                    }
                }
            }
        }

        if !foundCards.isEmpty {
            Section("Cartas (\(foundCards.reduce(0) { $0 + $1.1 }))") {
                ForEach(foundCards, id: \.0.id) { card, qty in
                    HStack {
                        CardImageView(url: card.media.imageUrl, width: 40, height: 56)
                        Text(card.name)
                            .font(.subheadline)
                        Spacer()
                        Text("×\(qty)")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.secondary)

                        let owned = collectionStore.quantity(for: card.id)
                        if owned < qty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                }
            }
        }

        if !missingCodes.isEmpty {
            Section("Cartas não encontradas") {
                ForEach(missingCodes, id: \.cardCode) { card in
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                        Text(card.cardCode)
                            .font(.subheadline.monospaced())
                        Spacer()
                        Text("×\(card.count)")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        if resolvedLegend != nil {
            Section {
                Button {
                    saveDeck(legend: resolvedLegend!, cards: foundCards)
                } label: {
                    HStack {
                        Spacer()
                        Text("Guardar Deck")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
    }

    private func importDeck() {
        error = nil
        decoded = nil

        let code = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        // Ensure card cache is loaded
        if !cardCache.isLoaded {
            isLoading = true
            Task {
                await cardCache.loadIfNeeded()
                isLoading = false
                doDecode(code)
            }
        } else {
            doDecode(code)
        }
    }

    private func doDecode(_ code: String) {
        do {
            decoded = try DeckCodec.decode(code)
        } catch let err as DeckCodecError {
            error = err.errorDescription
        } catch {
            self.error = "Erro ao descodificar: \(error.localizedDescription)"
        }
    }

    private func findCard(code: String) -> Card? {
        // Parse "OGN-007" → setId="OGN", number=7
        let parts = code.split(separator: "-", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let setCode = String(parts[0])

        // Extract number portion (strip variant suffix)
        var numStr = ""
        for ch in parts[1] {
            if ch.isNumber { numStr.append(ch) } else { break }
        }
        guard let number = Int(numStr) else { return nil }

        return cardCache.allCards.first { card in
            card.set.setId == setCode && card.collectorNumber == number
        }
    }

    private func resolved(forCode code: String?) -> Card? {
        guard let code else { return nil }
        return findCard(code: code)
    }

    private func saveDeck(legend: Card, cards: [(Card, Int)]) {
        let entries = cards.map { DeckEntry(card: $0.0, quantity: $0.1) }
        let deck = Deck(
            id: UUID(),
            name: "Deck de \(legend.name)",
            legend: legend,
            entries: entries,
            createdAt: Date()
        )
        deckStore.addDeck(deck)
        dismiss()
    }
}
