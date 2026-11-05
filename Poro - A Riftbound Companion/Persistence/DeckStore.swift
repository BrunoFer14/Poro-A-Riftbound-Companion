import Foundation
import Observation

@Observable
final class DeckStore {
    private(set) var decks: [Deck] = []
    var authUid: String?

    private let storageKey = "poro_decks_v1"

    init() {
        load()
    }

    func addDeck(_ deck: Deck) {
        decks.append(deck)
        save()
        syncDeck(deck)
    }

    func updateDeck(_ deck: Deck) {
        guard let index = decks.firstIndex(where: { $0.id == deck.id }) else { return }
        decks[index] = deck
        save()
        syncDeck(deck)
    }

    func deleteDeck(id: UUID) {
        decks.removeAll { $0.id == id }
        save()
        syncDeleteDeck(id: id)
    }

    func replaceAll(_ newDecks: [Deck]) {
        decks = newDecks
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

    // MARK: - Firestore Write-Through

    private func syncDeck(_ deck: Deck) {
        guard let uid = authUid else { return }
        Task {
            do {
                try await FirestoreService.saveDeck(uid: uid, deck: deck)
            } catch {
                #if DEBUG
                print("⚠️ Failed to sync deck \(deck.name): \(error)")
                #endif
            }
        }
    }

    private func syncDeleteDeck(id: UUID) {
        guard let uid = authUid else { return }
        Task {
            do {
                try await FirestoreService.deleteDeck(uid: uid, deckId: id)
            } catch {
                #if DEBUG
                print("⚠️ Failed to delete deck \(id): \(error)")
                #endif
            }
        }
    }
}
