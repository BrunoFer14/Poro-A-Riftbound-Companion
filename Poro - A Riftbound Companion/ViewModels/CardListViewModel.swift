import Foundation
import Observation

enum CardSortOption: String, CaseIterable {
    case name = "Nome"
    case energy = "Energia"
    case might = "Might"
    case power = "Power"
    case rarity = "Raridade"
    case collectorNumber = "Nº Colecionador"

    var icon: String {
        switch self {
        case .name: "textformat.abc"
        case .energy: "bolt.fill"
        case .might: "flame.fill"
        case .power: "star.fill"
        case .rarity: "sparkles"
        case .collectorNumber: "number"
        }
    }

    private static let rarityOrder: [String: Int] = [
        "Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Legendary": 4, "Showcase": 5
    ]

    func compare(_ a: Card, _ b: Card) -> Bool {
        switch self {
        case .name:
            return a.name.localizedCompare(b.name) == .orderedAscending
        case .energy:
            return (a.attributes.energy ?? 0) < (b.attributes.energy ?? 0)
        case .might:
            return (a.attributes.might ?? 0) < (b.attributes.might ?? 0)
        case .power:
            return (a.attributes.power ?? 0) < (b.attributes.power ?? 0)
        case .rarity:
            let ra = Self.rarityOrder[a.classification.rarity] ?? 99
            let rb = Self.rarityOrder[b.classification.rarity] ?? 99
            return ra < rb
        case .collectorNumber:
            return a.collectorNumber < b.collectorNumber
        }
    }
}

@Observable
final class CardListViewModel {
    private(set) var displayedCards: [Card] = []
    private(set) var isLoading = false
    private(set) var isSearchActive = false
    private(set) var isFuzzySearching = false   // kept for view compatibility; always false
    private(set) var totalLoaded = 0
    var errorMessage: String?

    var filter = CardFilter() {
        didSet { applyFilterAndSearch() }
    }

    var sortOption: CardSortOption = .collectorNumber {
        didSet { applyFilterAndSearch() }
    }

    var sortAscending: Bool = true {
        didSet { applyFilterAndSearch() }
    }

    var availableDomains: [String] {
        Array(Set(allCards.flatMap { $0.classification.domain })).sorted()
    }

    var availableEnergyCosts: [Int] {
        Array(Set(allCards.compactMap { $0.attributes.energy })).sorted()
    }

    var availableTypes: [String] {
        let typeOrder = ["Legend", "Unit", "Gear", "Spell", "Battlefield"]
        let present = Set(allCards.map { $0.classification.type })
        return typeOrder.filter { present.contains($0) }
    }

    var availableRarities: [String] {
        let rarityOrder = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Showcase"]
        let present = Set(allCards.map { $0.classification.rarity })
        return rarityOrder.filter { present.contains($0) }
    }

    var availableSets: [String] {
        Array(Set(allCards.map { $0.set.label })).sorted()
    }

    // Internal state
    private var allCards: [Card] = []
    private var activeQuery = ""
    private var currentSetId: String?

    // MARK: - Public API

    /// Loads all cards from all sets using the shared cache.
    func loadAllCards(from cache: CardCache) async {
        guard allCards.isEmpty, !isLoading else { return }
        currentSetId = nil
        await loadFromCache(cache, setId: nil)
    }

    /// Loads cards for a specific set using the shared cache.
    func loadCards(forSetId setId: String, cache: CardCache) async {
        guard allCards.isEmpty, !isLoading else { return }
        currentSetId = setId
        await loadFromCache(cache, setId: setId)
    }

    /// Loads all cards for a given set, using the shared cache when available.
    func loadCards(forSet setLabel: String, cache: CardCache) async {
        guard allCards.isEmpty, !isLoading else { return }

        if cache.isLoaded {
            allCards = cache.cards(forSet: setLabel)
            totalLoaded = allCards.count
            applyFilterAndSearch()
            return
        }

        isLoading = true
        errorMessage = nil
        await cache.loadIfNeeded()

        if cache.isLoaded {
            allCards = cache.cards(forSet: setLabel)
            totalLoaded = allCards.count
            isLoading = false
            applyFilterAndSearch()
        } else {
            errorMessage = "Não foi possível carregar as cartas."
            isLoading = false
        }
    }

    /// Called by the view with debounced text — client-side only, no API fallback.
    func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        activeQuery = trimmed
        isSearchActive = !trimmed.isEmpty
        applyFilterAndSearch()
    }

    // MARK: - Private

    private func loadFromCache(_ cache: CardCache, setId: String?) async {
        if cache.isLoaded {
            allCards = setId != nil ? cache.cards(forSetId: setId!) : cache.allCards
            totalLoaded = allCards.count
            applyFilterAndSearch()
            return
        }

        isLoading = true
        errorMessage = nil
        await cache.loadIfNeeded()

        if cache.isLoaded {
            allCards = setId != nil ? cache.cards(forSetId: setId!) : cache.allCards
            totalLoaded = allCards.count
            isLoading = false
            applyFilterAndSearch()
        } else {
            errorMessage = "Não foi possível carregar as cartas."
            isLoading = false
        }
    }

    private func applyFilterAndSearch() {
        var result = allCards

        if !activeQuery.isEmpty {
            let q = activeQuery
            result = result.filter { $0.name.localizedCaseInsensitiveContains(q) }
        }

        if filter.isActive {
            result = result.filter { filter.matches($0) }
        }

        result.sort { a, b in
            let ascending = sortOption.compare(a, b)
            return sortAscending ? ascending : !ascending
        }

        displayedCards = result
    }
}
