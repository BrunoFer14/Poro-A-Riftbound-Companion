import Foundation
import Observation

@Observable
final class CollectionStore {
    private(set) var entries: [CollectionEntry] = []

    private let storageKey = "poro_collection_v1"

    init() {
        load()
    }

    var totalCards: Int {
        entries.reduce(0) { $0 + $1.quantity }
    }

    var uniqueCards: Int {
        entries.count
    }

    func quantity(for cardId: String) -> Int {
        entries.first { $0.id == cardId }?.quantity ?? 0
    }

    func increment(_ card: Card) {
        if let index = entries.firstIndex(where: { $0.id == card.id }) {
            entries[index].quantity += 1
        } else {
            entries.append(CollectionEntry(card: card, quantity: 1))
        }
        save()
    }

    func decrement(_ card: Card) {
        guard let index = entries.firstIndex(where: { $0.id == card.id }) else { return }
        if entries[index].quantity <= 1 {
            entries.remove(at: index)
        } else {
            entries[index].quantity -= 1
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CollectionEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
