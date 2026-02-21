import Foundation

struct Card: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let riftboundId: String
    let tcgplayerId: String?
    let publicCode: String
    let collectorNumber: Int
    let attributes: CardAttributes
    let classification: CardClassification
    let text: CardText
    let set: CardSetRef
    let media: CardMedia
    let tags: [String]
    let orientation: String
    let metadata: CardMetadata

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case riftboundId = "riftbound_id"
        case tcgplayerId = "tcgplayer_id"
        case publicCode = "public_code"
        case collectorNumber = "collector_number"
        case attributes, classification, text, set, media, tags, orientation, metadata
    }
}

struct CardAttributes: Codable, Hashable {
    let energy: Int?
    let might: Int?
    let power: Int?
}

struct CardClassification: Codable, Hashable {
    let type: String
    let supertype: String?
    let rarity: String
    let domain: [String]
}

struct CardText: Codable, Hashable {
    let rich: String
    let plain: String
}

struct CardSetRef: Codable, Hashable {
    let setId: String
    let label: String

    enum CodingKeys: String, CodingKey {
        case setId = "set_id"
        case label
    }
}

struct CardMedia: Codable, Hashable {
    let imageUrl: String
    let artist: String
    let accessibilityText: String

    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case artist
        case accessibilityText = "accessibility_text"
    }
}

struct CardMetadata: Codable, Hashable {
    let cleanName: String
    let alternateArt: Bool
    let overnumbered: Bool
    let signature: Bool

    enum CodingKeys: String, CodingKey {
        case cleanName = "clean_name"
        case alternateArt = "alternate_art"
        case overnumbered
        case signature
    }
}

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let page: Int
    let size: Int
    let pages: Int
}
