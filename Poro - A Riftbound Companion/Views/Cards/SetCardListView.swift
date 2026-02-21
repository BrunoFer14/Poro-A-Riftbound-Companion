import SwiftUI

struct SetCardListView: View {
    let set: CardSetDetail
    let collectionStore: CollectionStore
    let cardCache: CardCache

    @State private var viewModel = CardListViewModel()
    @State private var showFilters = false
    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var isDebouncing = false

    var body: some View {
        @Bindable var vm = viewModel

        Group {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("A carregar cartas...")
                        .foregroundStyle(.secondary)
                    if viewModel.totalLoaded > 0 {
                        Text("\(viewModel.totalLoaded) de \(set.cardCount)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Erro ao carregar",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .overlay(alignment: .bottom) {
                    Button("Tentar novamente") {
                        Task { await viewModel.loadCards(forSet: set.label, cache: cardCache) }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
            } else {
                List {
                    ForEach(viewModel.displayedCards) { card in
                        NavigationLink(value: card) {
                            CardRowView(
                                card: card,
                                quantity: collectionStore.quantity(for: card.id),
                                onAdd: { collectionStore.increment(card) },
                                onRemove: { collectionStore.decrement(card) }
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    emptyStateOverlay
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button {
                                showFilters = true
                            } label: {
                                Image(systemName: viewModel.filter.isActive
                                      ? "line.3.horizontal.decrease.circle.fill"
                                      : "line.3.horizontal.decrease.circle")
                            }
                            Button {
                                withAnimation {
                                    isSearching.toggle()
                                    if !isSearching {
                                        searchText = ""
                                        viewModel.search(query: "")
                                    } else {
                                        searchFocused = true
                                    }
                                }
                            } label: {
                                Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    if isSearching {
                        HStack(spacing: 8) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Pesquisar cartas...", text: $searchText)
                                    .focused($searchFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        viewModel.search(query: "")
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(.quaternary, in: .rect(cornerRadius: 10))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .background(.bar)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .task(id: searchText) {
                    guard !searchText.isEmpty else {
                        isDebouncing = false
                        viewModel.search(query: "")
                        return
                    }
                    isDebouncing = true
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    isDebouncing = false
                    viewModel.search(query: searchText)
                }
                .sheet(isPresented: $showFilters) {
                    CardFilterView(
                        filter: $vm.filter,
                        availableDomains: viewModel.availableDomains,
                        availableEnergyCosts: viewModel.availableEnergyCosts
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }
        .navigationTitle(set.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Card.self) { card in
            CardDetailView(card: card, collectionStore: collectionStore)
        }
        .task {
            await viewModel.loadCards(forSet: set.label, cache: cardCache)
        }
    }

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if viewModel.displayedCards.isEmpty {
            if isDebouncing {
                Color.clear
            } else if viewModel.filter.isActive {
                ContentUnavailableView(
                    "Sem resultados",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Nenhuma carta corresponde aos filtros selecionados.")
                )
                .background(.background)
            } else if viewModel.isSearchActive {
                ContentUnavailableView.search(text: searchText)
                    .background(.background)
            }
        }
    }
}
