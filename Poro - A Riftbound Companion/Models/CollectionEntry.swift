import Foundation

struct CollectionEntry: Codable, Identifiable {
    let card: Card
    var quantity: Int
    var foilQuantity: Int
    var promoQuantity: Int

    var id: String { card.id }
    var totalQuantity: Int { quantity + foilQuantity + promoQuantity }

    init(card: Card, quantity: Int, foilQuantity: Int = 0, promoQuantity: Int = 0) {
        self.card = card
        self.quantity = quantity
        self.foilQuantity = foilQuantity
        self.promoQuantity = promoQuantity
    }

    // Backwards-compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        card = try container.decode(Card.self, forKey: .card)
        quantity = try container.decode(Int.self, forKey: .quantity)
        foilQuantity = try container.decodeIfPresent(Int.self, forKey: .foilQuantity) ?? 0
        promoQuantity = try container.decodeIfPresent(Int.self, forKey: .promoQuantity) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case card, quantity, foilQuantity, promoQuantity
    }
}
