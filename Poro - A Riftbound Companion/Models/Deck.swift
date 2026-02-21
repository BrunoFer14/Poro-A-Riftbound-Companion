import Foundation

struct DeckEntry: Codable, Identifiable, Hashable {
    let card: Card
    var quantity: Int

    var id: String { card.id }
}

struct Deck: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let legend: Card
    var entries: [DeckEntry]
    let createdAt: Date

    var totalCards: Int {
        entries.reduce(0) { $0 + $1.quantity }
    }

    var isComplete: Bool {
        totalCards == 40
    }

    var domains: [String] {
        legend.classification.domain
    }

    func quantity(for cardId: String) -> Int {
        entries.first { $0.card.id == cardId }?.quantity ?? 0
    }

    mutating func addCard(_ card: Card, ownedQuantity: Int = .max) {
        guard totalCards < 40 else { return }
        let currentQty = quantity(for: card.id)
        let limit = min(3, ownedQuantity)
        guard currentQty < limit else { return }
        if let index = entries.firstIndex(where: { $0.card.id == card.id }) {
            entries[index].quantity += 1
        } else {
            entries.append(DeckEntry(card: card, quantity: 1))
        }
    }

    mutating func removeCard(_ card: Card) {
        guard let index = entries.firstIndex(where: { $0.card.id == card.id }) else { return }
        if entries[index].quantity <= 1 {
            entries.remove(at: index)
        } else {
            entries[index].quantity -= 1
        }
    }
}
