import Foundation
import Observation

@Observable
final class CardListViewModel {
    private(set) var displayedCards: [Card] = []
    private(set) var isLoading = false
    private(set) var isSearchActive = false
    private(set) var totalLoaded = 0
    var errorMessage: String?

    var filter = CardFilter() {
        didSet { applyFilterAndSearch() }
    }

    var availableDomains: [String] {
        Array(Set(allCards.flatMap { $0.classification.domain })).sorted()
    }

    var availableEnergyCosts: [Int] {
        Array(Set(allCards.compactMap { $0.attributes.energy })).sorted()
    }

    // Internal state
    private var allCards: [Card] = []
    private var activeQuery = ""

    // MARK: - Public API

    /// Loads all cards for a given set, using the shared cache when available.
    func loadCards(forSet setLabel: String, cache: CardCache) async {
        guard allCards.isEmpty, !isLoading else { return }

        // Check cache first — instant if already loaded
        if cache.isLoaded {
            allCards = cache.cards(forSet: setLabel)
            totalLoaded = allCards.count
            applyFilterAndSearch()
            return
        }

        // First time: fetch from API and populate cache
        isLoading = true
        errorMessage = nil
        totalLoaded = 0

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

    /// Called by the view with debounced text.
    func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        activeQuery = trimmed
        isSearchActive = !trimmed.isEmpty
        applyFilterAndSearch()
    }

    // MARK: - Private

    private func applyFilterAndSearch() {
        var result = allCards

        if !activeQuery.isEmpty {
            let q = activeQuery
            result = result.filter { $0.name.localizedCaseInsensitiveContains(q) }
        }

        if filter.isActive {
            result = result.filter { filter.matches($0) }
        }

        displayedCards = result
    }
}
