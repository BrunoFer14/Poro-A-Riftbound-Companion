import SwiftUI

struct CollectionView: View {
    let collectionStore: CollectionStore

    @State private var searchText = ""
    @State private var filter = CardFilter()
    @State private var showFilters = false

    private var availableDomains: [String] {
        Array(Set(collectionStore.entries.flatMap { $0.card.classification.domain })).sorted()
    }

    private var availableEnergyCosts: [Int] {
        Array(Set(collectionStore.entries.compactMap { $0.card.attributes.energy })).sorted()
    }

    private var availableSets: [String] {
        Array(Set(collectionStore.entries.map { $0.card.set.label })).sorted()
    }

    private var filteredEntries: [CollectionEntry] {
        var result = collectionStore.entries.sorted { $0.card.name < $1.card.name }
        if !searchText.isEmpty {
            result = result.filter { $0.card.name.localizedCaseInsensitiveContains(searchText) }
        }
        if filter.isActive {
            result = result.filter { filter.matches($0.card) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if collectionStore.entries.isEmpty {
                    ContentUnavailableView(
                        "Coleção vazia",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Adiciona cartas à tua coleção no separador Cartas.")
                    )
                } else if filteredEntries.isEmpty {
                    if filter.isActive {
                        ContentUnavailableView(
                            "Sem resultados",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Nenhuma carta corresponde aos filtros selecionados.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    List {
                        Section {
                            HStack {
                                Label(
                                    "\(collectionStore.uniqueCards) carta\(collectionStore.uniqueCards == 1 ? "" : "s") única\(collectionStore.uniqueCards == 1 ? "" : "s")",
                                    systemImage: "rectangle.on.rectangle"
                                )
                                Spacer()
                                Label("\(collectionStore.totalCards) no total", systemImage: "sum")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)

                        Section {
                            ForEach(filteredEntries) { entry in
                                NavigationLink(value: entry.card) {
                                    CollectionRowView(entry: entry, collectionStore: collectionStore)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Coleção")
            .searchable(text: $searchText, prompt: "Pesquisar coleção...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                CardFilterView(
                    filter: $filter,
                    availableDomains: availableDomains,
                    availableEnergyCosts: availableEnergyCosts,
                    availableSets: availableSets
                )
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(for: Card.self) { card in
                CardDetailView(card: card, collectionStore: collectionStore)
            }
        }
    }
}
