import Foundation

struct CollectionEntry: Codable, Identifiable {
    let card: Card
    var quantity: Int

    var id: String { card.id }
}
