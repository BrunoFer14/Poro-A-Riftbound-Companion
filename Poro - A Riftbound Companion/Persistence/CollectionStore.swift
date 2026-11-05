import Foundation
import Observation

@Observable
final class CollectionStore {
    private(set) var entries: [CollectionEntry] = []
    var authUid: String?

    private let storageKey = "poro_collection_v2"

    init() {
        load()
    }

    var totalCards: Int {
        entries.reduce(0) { $0 + $1.totalQuantity }
    }

    var uniqueCards: Int {
        entries.count
    }

    func quantity(for cardId: String) -> Int {
        entries.first { $0.id == cardId }?.quantity ?? 0
    }

    func foilQuantity(for cardId: String) -> Int {
        entries.first { $0.id == cardId }?.foilQuantity ?? 0
    }

    func promoQuantity(for cardId: String) -> Int {
        entries.first { $0.id == cardId }?.promoQuantity ?? 0
    }

    func totalQuantity(for cardId: String) -> Int {
        guard let entry = entries.first(where: { $0.id == cardId }) else { return 0 }
        return entry.totalQuantity
    }

    private var isEmpty: Bool { entries.isEmpty }

    // MARK: - Normal

    func increment(_ card: Card) {
        if let index = entries.firstIndex(where: { $0.id == card.id }) {
            entries[index].quantity += 1
        } else {
            entries.append(CollectionEntry(card: card, quantity: 1))
        }
        save(); syncEntry(cardId: card.id)
    }

    func decrement(_ card: Card) {
        guard let index = entries.firstIndex(where: { $0.id == card.id }) else { return }
        entries[index].quantity = max(0, entries[index].quantity - 1)
        removeIfEmpty(at: index)
    }

    // MARK: - Foil

    func incrementFoil(_ card: Card) {
        if let index = entries.firstIndex(where: { $0.id == card.id }) {
            entries[index].foilQuantity += 1
        } else {
            entries.append(CollectionEntry(card: card, quantity: 0, foilQuantity: 1))
        }
        save(); syncEntry(cardId: card.id)
    }

    func decrementFoil(_ card: Card) {
        guard let index = entries.firstIndex(where: { $0.id == card.id }) else { return }
        entries[index].foilQuantity = max(0, entries[index].foilQuantity - 1)
        removeIfEmpty(at: index)
    }

    // MARK: - Promo

    func incrementPromo(_ card: Card) {
        if let index = entries.firstIndex(where: { $0.id == card.id }) {
            entries[index].promoQuantity += 1
        } else {
            entries.append(CollectionEntry(card: card, quantity: 0, promoQuantity: 1))
        }
        save(); syncEntry(cardId: card.id)
    }

    func decrementPromo(_ card: Card) {
        guard let index = entries.firstIndex(where: { $0.id == card.id }) else { return }
        entries[index].promoQuantity = max(0, entries[index].promoQuantity - 1)
        removeIfEmpty(at: index)
    }

    // MARK: - Shared

    func replaceAll(_ newEntries: [CollectionEntry]) {
        entries = newEntries
        save()
    }

    func resetSet(_ setId: String) {
        let toDelete = entries.filter { $0.card.set.setId == setId }.map(\.card.id)
        entries.removeAll { $0.card.set.setId == setId }
        save()
        for cardId in toDelete { syncDeleteEntry(cardId: cardId) }
    }

    // MARK: - Private

    private func removeIfEmpty(at index: Int) {
        let e = entries[index]
        if e.quantity == 0 && e.foilQuantity == 0 && e.promoQuantity == 0 {
            let cardId = e.card.id
            entries.remove(at: index)
            save(); syncDeleteEntry(cardId: cardId)
        } else {
            save(); syncEntry(cardId: entries[index].card.id)
        }
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

    // MARK: - Firestore

    private func syncEntry(cardId: String) {
        guard let uid = authUid else { return }
        let qty = quantity(for: cardId)
        let foilQty = foilQuantity(for: cardId)
        let promoQty = promoQuantity(for: cardId)
        Task {
            do {
                try await FirestoreService.saveCollectionEntry(uid: uid, cardId: cardId, quantity: qty, foilQuantity: foilQty, promoQuantity: promoQty)
            } catch {
                #if DEBUG
                print("⚠️ Failed to sync collection entry \(cardId): \(error)")
                #endif
            }
        }
    }

    private func syncDeleteEntry(cardId: String) {
        guard let uid = authUid else { return }
        Task {
            do {
                try await FirestoreService.deleteCollectionEntry(uid: uid, cardId: cardId)
            } catch {
                #if DEBUG
                print("⚠️ Failed to delete collection entry \(cardId): \(error)")
                #endif
            }
        }
    }
}
