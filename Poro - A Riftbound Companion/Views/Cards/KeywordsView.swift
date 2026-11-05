import SwiftUI

struct KeywordsView: View {
    let cardCache: CardCache

    @State private var keywords: [String] = []
    @State private var isLoading = true
    @State private var searchText = ""

    private var filteredKeywords: [String] {
        if searchText.isEmpty { return keywords }
        return keywords.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("A carregar keywords...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredKeywords.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredKeywords, id: \.self) { keyword in
                    NavigationLink(value: keyword) {
                        Label(keyword, systemImage: "text.book.closed")
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Keywords")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Pesquisar keywords...")
        .navigationDestination(for: String.self) { keyword in
            KeywordCardsView(keyword: keyword, cardCache: cardCache)
        }
        .task {
            await loadKeywords()
        }
    }

    private func loadKeywords() async {
        await cardCache.loadIfNeeded()
        let pattern = /\[([A-Za-z][^\]]+)\]/
        var seen = Set<String>()
        for card in cardCache.allCards {
            for match in card.text.plain.matches(of: pattern) {
                seen.insert(String(match.1))
            }
        }
        keywords = seen.sorted()
        isLoading = false
    }
}

// MARK: - Cards for a keyword

private struct KeywordCardsView: View {
    let keyword: String
    let cardCache: CardCache

    @State private var cards: [Card] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cards.isEmpty {
                ContentUnavailableView(
                    "Sem cartas",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("Nenhuma carta encontrada com esta keyword.")
                )
            } else {
                List(cards) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(card.name)
                                .font(.headline)
                            Spacer()
                            Text(card.set.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(card.text.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(keyword)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCards()
        }
    }

    private func loadCards() async {
        await cardCache.loadIfNeeded()
        let target = "[\(keyword)]"
        cards = cardCache.allCards.filter { $0.text.plain.contains(target) }
        isLoading = false
    }
}
