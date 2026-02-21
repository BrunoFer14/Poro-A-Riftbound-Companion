import Foundation
import Observation

/// In-memory cache for all cards. Lives for the duration of the app process —
/// cleared automatically when the app is terminated (no disk persistence).
@Observable
final class CardCache {
    private(set) var allCards: [Card] = []
    private(set) var isLoaded = false
    private var isLoading = false

    func cards(forSet label: String) -> [Card] {
        allCards.filter { $0.set.label == label }
    }

    /// Loads all cards from the API if not already cached.
    func loadIfNeeded() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true

        var page = 1
        var hasMore = true
        var fetched: [Card] = []

        while hasMore {
            do {
                let response = try await CardService.fetchCards(page: page, size: 100)
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }
                fetched += response.items
                hasMore = page < response.pages
                page += 1
            } catch {
                break
            }
        }

        allCards = fetched
        isLoaded = true
        isLoading = false
    }
}
