import Foundation
import Observation

/// In-memory cache for all cards. Uses RiftHunt /bulk/cards for a single-request load.
/// Lives for the duration of the app process — cleared automatically on termination.
@Observable
final class CardCache {
    private(set) var allCards: [Card] = []
    private(set) var isLoaded = false
    private(set) var isLoading = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func cards(forSet label: String) -> [Card] {
        allCards.filter { $0.set.label == label }
    }

    func cards(forSetId id: String) -> [Card] {
        allCards.filter { $0.set.setId == id }
    }

    /// All unique set IDs with their display names, sorted by set code.
    var setInfos: [(setId: String, name: String)] {
        var seen = Set<String>()
        return allCards
            .filter { seen.insert($0.set.setId).inserted }
            .map { (setId: $0.set.setId, name: $0.set.label) }
            .sorted { $0.name < $1.name }
    }

    /// Find other versions of a card (alt art, signature, promo, cross-set).
    func otherVersions(of card: Card) -> [Card] {
        let baseName = card.name
            .replacingOccurrences(of: " (Alternate Art)", with: "")
            .replacingOccurrences(of: " (Signature)", with: "")

        return allCards.filter { other in
            guard other.id != card.id else { return false }

            if other.collectorNumber == card.collectorNumber && other.set.setId == card.set.setId {
                return true
            }

            let otherBase = other.name
                .replacingOccurrences(of: " (Alternate Art)", with: "")
                .replacingOccurrences(of: " (Signature)", with: "")
            return otherBase == baseName
        }
    }

    /// Loads all cards from the RiftHunt bulk endpoint in a single request.
    /// Multiple concurrent callers wait for the same load to finish.
    func loadIfNeeded() async {
        if isLoaded { return }

        if isLoading {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
            return
        }

        isLoading = true

        do {
            let response: BulkCardsResponse = try await APIClient.fetch("/bulk/cards")
            var seen = Set<String>()
            allCards = response.cards.filter { seen.insert($0.id).inserted }
            isLoaded = !allCards.isEmpty
        } catch {
            #if DEBUG
            print("⚠️ CardCache: bulk load failed: \(error)")
            #endif
        }

        isLoading = false
        resumeWaiters()
    }

    private func resumeWaiters() {
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}

// MARK: - Bulk response

private struct BulkCardsResponse: Decodable {
    let cards: [Card]
}
