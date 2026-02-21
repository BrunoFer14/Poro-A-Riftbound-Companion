import SwiftUI

struct CardListView: View {
    let collectionStore: CollectionStore

    @State private var cardCache = CardCache()
    @State private var sets: [CardSetDetail] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("A carregar expansões...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Erro ao carregar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .overlay(alignment: .bottom) {
                        Button("Tentar novamente") {
                            Task { await loadSets() }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 40)
                    }
                } else {
                    List(sets) { set in
                        NavigationLink(value: set) {
                            SetRowView(set: set)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cartas")
            .navigationDestination(for: CardSetDetail.self) { set in
                SetCardListView(set: set, collectionStore: collectionStore, cardCache: cardCache)
            }
        }
        .task {
            await loadSets()
        }
    }

    private func loadSets() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await SetService.fetchSets()
            sets = response.items.sorted { $0.publishDate > $1.publishDate }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

private struct SetRowView: View {
    let set: CardSetDetail

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(set.name)
                    .font(.headline)
                Text("\(set.cardCount) cartas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
