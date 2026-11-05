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
    var battlefields: [Card]
    var runes: [String: Int]
    let createdAt: Date

    init(id: UUID, name: String, legend: Card, entries: [DeckEntry], battlefields: [Card] = [], runes: [String: Int] = [:], createdAt: Date) {
        self.id = id
        self.name = name
        self.legend = legend
        self.entries = entries
        self.battlefields = battlefields
        self.runes = runes
        self.createdAt = createdAt
    }

    // Backward-compatible decoding: supports old "locations" key
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        legend = try container.decode(Card.self, forKey: .legend)
        entries = try container.decode([DeckEntry].self, forKey: .entries)
        // Try "battlefields" first, fall back to "locations" for old data
        if let bf = try? container.decode([Card].self, forKey: .battlefields) {
            battlefields = bf
        } else {
            battlefields = (try? container.decode([Card].self, forKey: .locations)) ?? []
        }
        runes = (try? container.decode([String: Int].self, forKey: .runes)) ?? [:]
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, legend, entries, battlefields, locations, runes, createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(legend, forKey: .legend)
        try container.encode(entries, forKey: .entries)
        try container.encode(battlefields, forKey: .battlefields)
        try container.encode(runes, forKey: .runes)
        try container.encode(createdAt, forKey: .createdAt)
    }

    var totalCards: Int {
        entries.reduce(0) { $0 + $1.quantity }
    }

    var hasAllBattlefields: Bool {
        battlefields.count == 3
    }

    var totalRunes: Int {
        runes.values.reduce(0, +)
    }

    var hasAllRunes: Bool {
        totalRunes == 12
    }

    var isComplete: Bool {
        totalCards == 40 && hasAllBattlefields && hasAllRunes
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

    mutating func addBattlefield(_ card: Card) {
        guard battlefields.count < 3 else { return }
        guard !battlefields.contains(where: { $0.id == card.id }) else { return }
        battlefields.append(card)
    }

    mutating func removeBattlefield(_ card: Card) {
        battlefields.removeAll { $0.id == card.id }
    }
}
