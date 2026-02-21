import Foundation
import Observation

@Observable
final class DeckStore {
    private(set) var decks: [Deck] = []

    private let storageKey = "poro_decks_v1"

    init() {
        load()
    }

    func addDeck(_ deck: Deck) {
        decks.append(deck)
        save()
    }

    func updateDeck(_ deck: Deck) {
        guard let index = decks.firstIndex(where: { $0.id == deck.id }) else { return }
        decks[index] = deck
        save()
    }

    func deleteDeck(id: UUID) {
        decks.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(decks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Deck].self, from: data)
        else { return }
        decks = decoded
    }
}
