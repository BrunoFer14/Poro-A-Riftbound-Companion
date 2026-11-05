import SwiftUI
import FirebaseAuth

// MARK: - Missing Mode

enum MissingMode: String, CaseIterable {
    case none = "Coleção"
    case missingCards = "Em Falta"
    case missingPlayset = "Playset Incompleto"

    var icon: String {
        switch self {
        case .none: "rectangle.stack.fill"
        case .missingCards: "eye.slash"
        case .missingPlayset: "chart.bar"
        }
    }
}

// MARK: - Playset Limit

private func playsetLimit(for card: Card) -> Int {
    switch card.classification.type {
    case "Legend", "Battlefield": return 1
    default: return 3
    }
}

// MARK: - CollectionSetView

struct CollectionSetView: View {
    let authService: AuthService
    let collectionStore: CollectionStore
    let cardCache: CardCache
    let setId: String? // nil = all sets

    @State private var searchText = ""
    @State private var filter = CardFilter()
    @State private var showFilters = false
    @State private var sortOption: CollectionSortOption = .name
    @State private var missingMode: MissingMode = .none
    @State private var cardToSell: Card? = nil
    @State private var cardToBuy: Card? = nil
    @State private var sellViewModel = MarketplaceViewModel()

    /// All cards for this set, loaded from the API (not the global cache).
    @State private var setCards: [Card] = []
    @State private var isLoadingSetCards = false

    private var title: String {
        if let setId {
            // Use name from entries first, then cache, then raw ID
            if let name = collectionStore.entries.first(where: { $0.card.set.setId == setId })?.card.set.label {
                return name
            }
            return cardCache.setInfos.first { $0.setId == setId }?.name ?? setId
        }
        return "Todas"
    }

    // MARK: - Data

    private var allSetCards: [Card] {
        if setId != nil {
            return setCards
        }
        return cardCache.allCards
    }

    private var setEntries: [CollectionEntry] {
        if let setId {
            return collectionStore.entries.filter { $0.card.set.setId == setId }
        }
        return collectionStore.entries
    }

    private var quantityById: [String: Int] {
        Dictionary(collectionStore.entries.map { ($0.card.id, $0.totalQuantity) }, uniquingKeysWith: { $1 })
    }

    private var cardById: [String: Card] {
        Dictionary(collectionStore.entries.map { ($0.card.id, $0.card) }, uniquingKeysWith: { $1 })
    }

    private var entryById: [String: CollectionEntry] {
        Dictionary(collectionStore.entries.map { ($0.card.id, $0) }, uniquingKeysWith: { $1 })
    }

    private var displayedEntries: [CollectionEntry] {
        var result: [CollectionEntry]

        switch missingMode {
        case .none:
            result = setEntries

        case .missingCards:
            let ownedIds = Set(setEntries.map { $0.card.id })
            let missing = allSetCards.filter { !ownedIds.contains($0.id) }
            result = missing.map { CollectionEntry(card: $0, quantity: 0) }

        case .missingPlayset:
            let qty = quantityById
            let existing = entryById
            result = allSetCards.compactMap { card in
                let current = qty[card.id] ?? 0
                let limit = playsetLimit(for: card)
                guard current < limit else { return nil }
                // Use stored entry if available (preserves foilQuantity)
                if let entry = existing[card.id] {
                    return entry
                }
                return CollectionEntry(card: card, quantity: 0)
            }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.card.name.localizedCaseInsensitiveContains(searchText) }
        }
        if filter.isActive {
            result = result.filter { filter.matches($0.card) }
        }
        return result.sorted(using: sortOption)
    }

    // MARK: - Progress

    private var progressOwned: Int {
        var seen = Set<String>()
        return setEntries.filter { seen.insert($0.card.id).inserted }.count
    }

    private var progressTotal: Int {
        allSetCards.count
    }

    private var missingCount: Int {
        switch missingMode {
        case .none: return 0
        case .missingCards:
            let ownedIds = Set(setEntries.map { $0.card.id })
            return allSetCards.filter { !ownedIds.contains($0.id) }.count
        case .missingPlayset:
            let qty = quantityById
            return allSetCards.filter { card in
                (qty[card.id] ?? 0) < playsetLimit(for: card)
            }.count
        }
    }

    // MARK: - Filter options

    private var availableDomains: [String] {
        Array(Set(displayedEntries.flatMap { $0.card.classification.domain })).sorted()
    }

    private var availableEnergyCosts: [Int] {
        Array(Set(displayedEntries.compactMap { $0.card.attributes.energy })).sorted()
    }

    private var availableTypes: [String] {
        let typeOrder = ["Legend", "Unit", "Gear", "Spell", "Battlefield"]
        let present = Set(displayedEntries.map { $0.card.classification.type })
        return typeOrder.filter { present.contains($0) }
    }

    private var availableRarities: [String] {
        let rarityOrder = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Showcase", "Promo"]
        let present = Set(displayedEntries.map { $0.card.classification.rarity })
        return rarityOrder.filter { present.contains($0) }
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    // MARK: - Body

    var body: some View {
        Group {
            if displayedEntries.isEmpty && missingMode == .none && !filter.isActive && searchText.isEmpty {
                ContentUnavailableView(
                    "Coleção vazia",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Adiciona cartas à tua coleção no separador Cartas.")
                )
            } else if displayedEntries.isEmpty && filter.isActive {
                ContentUnavailableView(
                    "Sem resultados",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Nenhuma carta corresponde aos filtros selecionados.")
                )
            } else if displayedEntries.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if displayedEntries.isEmpty && missingMode != .none {
                ContentUnavailableView(
                    missingMode == .missingCards ? "Tens todas as cartas!" : "Playset completo!",
                    systemImage: missingMode == .missingCards ? "checkmark.seal.fill" : "checkmark.circle.fill",
                    description: Text(missingMode == .missingCards
                        ? "Tens pelo menos uma cópia de cada carta."
                        : "Tens o playset completo de todas as cartas.")
                )
                .foregroundStyle(.green)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        statsBar
                        modePicker
                        cardGrid
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Pesquisar...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !allSetCards.isEmpty || cardCache.isLoaded {
                        missingMenu
                    }
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            CardFilterView(
                filter: $filter,
                availableDomains: availableDomains,
                availableEnergyCosts: availableEnergyCosts,
                availableTypes: availableTypes,
                availableRarities: availableRarities
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $cardToSell) { card in
            CreateListingView(
                authService: authService,
                cardCache: cardCache,
                viewModel: sellViewModel,
                preselectedCard: card
            )
        }
        .sheet(item: $cardToBuy) { card in
            CardListingsSheet(cardName: card.name, authService: authService)
        }
        .navigationDestination(for: Card.self) { card in
            CardDetailView(card: card, collectionStore: collectionStore, authService: authService, cardCache: cardCache)
        }
        .task {
            guard let setId, setCards.isEmpty else { return }
            await loadSetCards(setId: setId)
        }
    }

    // MARK: - Load Set Cards

    private func loadSetCards(setId: String) async {
        guard !isLoadingSetCards else { return }
        isLoadingSetCards = true
        defer { isLoadingSetCards = false }

        await cardCache.loadIfNeeded()
        setCards = cardCache.cards(forSetId: setId)
    }

    // MARK: - Subviews

    private var statsBar: some View {
        HStack {
            if !allSetCards.isEmpty || cardCache.isLoaded {
                Label("\(progressOwned) / \(progressTotal)", systemImage: "chart.bar.fill")
            }
            Spacer()
            if missingMode != .none {
                Label("\(missingCount) em falta", systemImage: missingMode.icon)
                    .foregroundStyle(.orange)
            } else {
                Label("\(setEntries.reduce(0) { $0 + $1.totalQuantity }) no total", systemImage: "sum")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CollectionSortOption.allCases, id: \.self) { option in
                    let isSelected = sortOption == option
                    Button {
                        withAnimation(.snappy) { sortOption = option }
                    } label: {
                        Text(option.rawValue)
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
    }

    private var cardGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayedEntries) { entry in
                NavigationLink(value: entry.card) {
                    CollectionGridCell(
                        entry: entry,
                        missingMode: missingMode
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if authService.isLoggedIn {
                        Button {
                            cardToBuy = entry.card
                        } label: {
                            Label("Comprar no mercado", systemImage: "magnifyingglass")
                        }
                        Button {
                            cardToSell = entry.card
                        } label: {
                            Label("Pôr à venda", systemImage: "tag")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var missingMenu: some View {
        Menu {
            ForEach(MissingMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation { missingMode = mode }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                    if missingMode == mode {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: missingMode == .none
                  ? "eye"
                  : missingMode == .missingCards
                    ? "eye.slash"
                    : "chart.bar")
            .symbolVariant(missingMode != .none ? .fill : .none)
            .foregroundStyle(missingMode != .none ? Color.accentColor : Color.primary)
        }
    }
}

// MARK: - Grid Cell

struct CollectionGridCell: View {
    let entry: CollectionEntry
    var missingMode: MissingMode = .none

    private var isMissing: Bool { entry.totalQuantity == 0 }
    private var limit: Int { playsetLimit(for: entry.card) }
    private var isPlaysetComplete: Bool { entry.totalQuantity >= limit }
    private var hasFoil: Bool { entry.foilQuantity > 0 }
    private var hasPromo: Bool { entry.promoQuantity > 0 }

    var body: some View {
        VStack(spacing: 6) {
            CardImageView(url: entry.card.media.imageUrl, width: 100, height: 140)
                .overlay(alignment: .topTrailing) {
                    quantityBadge
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        if hasFoil { foilBadge }
                        if hasPromo { promoBadge }
                    }
                    .padding(4)
                }
                .overlay(alignment: .bottom) {
                    if missingMode == .missingPlayset && !isMissing {
                        playsetBar
                    }
                }
                .opacity(cardOpacity)

            Text(entry.card.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(isMissing ? .secondary : .primary)
        }
    }

    @ViewBuilder
    private var quantityBadge: some View {
        if missingMode == .missingPlayset {
            Text("×\(entry.totalQuantity)/\(limit)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isMissing ? Color.red.opacity(0.8) : Color.orange.opacity(0.85), in: .capsule)
                .padding(4)
        } else if !isMissing {
            Text("×\(entry.totalQuantity)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.secondary, in: .capsule)
                .padding(4)
        }
    }

    private var foilBadge: some View {
        Text("✦\(entry.foilQuantity)")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    .opacity(0.85),
                in: .capsule
            )
    }

    private var promoBadge: some View {
        Text("P\(entry.promoQuantity)")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.85), in: .capsule)
    }

    @ViewBuilder
    private var playsetBar: some View {
        HStack(spacing: 3) {
            ForEach(0..<limit, id: \.self) { i in
                Circle()
                    .fill(i < entry.totalQuantity ? Color.accentColor : Color.white.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, 4)
    }

    private var cardOpacity: Double {
        if isMissing { return 0.35 }
        if missingMode == .missingPlayset && !isPlaysetComplete { return 0.75 }
        return 1.0
    }
}

// MARK: - Sort Extension

extension Array where Element == CollectionEntry {
    func sorted(using option: CollectionSortOption) -> [CollectionEntry] {
        switch option {
        case .name:
            sorted { $0.card.name < $1.card.name }
        case .runeCost:
            sorted { ($0.card.attributes.energy ?? 0) < ($1.card.attributes.energy ?? 0) }
        case .domain:
            sorted {
                let d0 = $0.card.classification.domain.first ?? ""
                let d1 = $1.card.classification.domain.first ?? ""
                if d0 != d1 { return d0 < d1 }
                return $0.card.name < $1.card.name
            }
        case .rarity:
            sorted {
                let order: [String: Int] = ["Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Legendary": 4, "Showcase": 5, "Promo": 6]
                let r0 = order[$0.card.classification.rarity] ?? 0
                let r1 = order[$1.card.classification.rarity] ?? 0
                if r0 != r1 { return r0 < r1 }
                return $0.card.name < $1.card.name
            }
        }
    }
}
