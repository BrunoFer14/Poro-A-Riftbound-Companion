import Foundation

struct CardSetDetail: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let setId: String
    let label: String
    let cardCount: Int
    let tcgplayerId: String?
    let cardmarketId: String?
    let publishDate: String
    let updateDate: String

    enum CodingKeys: String, CodingKey {
        case id, name, label
        case setId = "set_id"
        case cardCount = "card_count"
        case tcgplayerId = "tcgplayer_id"
        case cardmarketId = "cardmarket_id"
        case publishDate = "publish_date"
        case updateDate = "update_date"
    }
}
