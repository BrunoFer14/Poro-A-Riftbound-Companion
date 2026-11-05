import Foundation

struct CardSetDetail: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let setId: String      // uppercase set code, e.g. "RAD"
    let cardCount: Int
    let publishedOn: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case setId = "code"
        case cardCount = "card_count"
        case publishedOn = "release_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        setId = try c.decode(String.self, forKey: .setId).uppercased()
        cardCount = try c.decode(Int.self, forKey: .cardCount)
        publishedOn = try c.decode(String.self, forKey: .publishedOn)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(setId.lowercased(), forKey: .setId)
        try c.encode(cardCount, forKey: .cardCount)
        try c.encode(publishedOn, forKey: .publishedOn)
    }
}

/// RiftHunt wraps list responses in { object, has_more, data: [...] }
struct RiftHuntList<T: Codable>: Codable {
    let data: [T]
}
