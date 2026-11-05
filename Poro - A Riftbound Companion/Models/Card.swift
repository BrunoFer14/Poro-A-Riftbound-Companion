import Foundation

struct Card: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let riftboundId: String
    let collectorNumber: Int
    let attributes: CardAttributes
    let classification: CardClassification
    let text: CardText
    let set: CardSetRef
    let media: CardMedia
    let tags: [String]
    let orientation: String
    let metadata: CardMetadata

    // MARK: - Custom Codable for RiftHunt flat schema

    private enum CodingKeys: String, CodingKey {
        case id, name, tags, orientation
        case riftboundId
        case collectorNumber = "num"
        case energy, might, power
        case type, supertype, rarity, domains
        case plainText = "text"
        case rich, flavour
        case setCode = "set"
        case setName
        case imgUrl, artist
        case cleanName, alt, sig, over
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        riftboundId = try c.decodeIfPresent(String.self, forKey: .riftboundId) ?? id
        collectorNumber = try c.decode(Int.self, forKey: .collectorNumber)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        orientation = try c.decodeIfPresent(String.self, forKey: .orientation) ?? "portrait"

        attributes = CardAttributes(
            energy: try c.decodeIfPresent(Int.self, forKey: .energy),
            might: try c.decodeIfPresent(Int.self, forKey: .might),
            power: try c.decodeIfPresent(Int.self, forKey: .power)
        )
        classification = CardClassification(
            type: try c.decode(String.self, forKey: .type),
            supertype: try c.decodeIfPresent(String.self, forKey: .supertype),
            rarity: try c.decode(String.self, forKey: .rarity),
            domain: try c.decodeIfPresent([String].self, forKey: .domains) ?? []
        )
        text = CardText(
            rich: try c.decodeIfPresent(String.self, forKey: .rich) ?? "",
            plain: try c.decodeIfPresent(String.self, forKey: .plainText) ?? "",
            flavour: try c.decodeIfPresent(String.self, forKey: .flavour)
        )
        let setCode = try c.decode(String.self, forKey: .setCode)
        let setLabel = try c.decodeIfPresent(String.self, forKey: .setName) ?? setCode
        set = CardSetRef(setId: setCode, label: setLabel)

        media = CardMedia(
            imageUrl: try c.decodeIfPresent(String.self, forKey: .imgUrl) ?? "",
            artist: try c.decodeIfPresent(String.self, forKey: .artist) ?? ""
        )
        metadata = CardMetadata(
            cleanName: try c.decodeIfPresent(String.self, forKey: .cleanName),
            alternateArt: try c.decodeIfPresent(Bool.self, forKey: .alt) ?? false,
            overnumbered: try c.decodeIfPresent(Bool.self, forKey: .over) ?? false,
            signature: try c.decodeIfPresent(Bool.self, forKey: .sig) ?? false
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(riftboundId, forKey: .riftboundId)
        try c.encode(collectorNumber, forKey: .collectorNumber)
        try c.encode(tags, forKey: .tags)
        try c.encode(orientation, forKey: .orientation)
        try c.encodeIfPresent(attributes.energy, forKey: .energy)
        try c.encodeIfPresent(attributes.might, forKey: .might)
        try c.encodeIfPresent(attributes.power, forKey: .power)
        try c.encode(classification.type, forKey: .type)
        try c.encodeIfPresent(classification.supertype, forKey: .supertype)
        try c.encode(classification.rarity, forKey: .rarity)
        try c.encode(classification.domain, forKey: .domains)
        try c.encode(text.plain, forKey: .plainText)
        try c.encode(text.rich, forKey: .rich)
        try c.encodeIfPresent(text.flavour, forKey: .flavour)
        try c.encode(set.setId, forKey: .setCode)
        try c.encode(set.label, forKey: .setName)
        try c.encode(media.imageUrl, forKey: .imgUrl)
        try c.encode(media.artist, forKey: .artist)
        try c.encodeIfPresent(metadata.cleanName, forKey: .cleanName)
        try c.encode(metadata.alternateArt, forKey: .alt)
        try c.encode(metadata.overnumbered, forKey: .over)
        try c.encode(metadata.signature, forKey: .sig)
    }
}

// MARK: - Sub-types (keep same structure — no view changes needed)

struct CardAttributes: Hashable {
    let energy: Int?
    let might: Int?
    let power: Int?
}

struct CardClassification: Hashable {
    let type: String
    let supertype: String?
    let rarity: String
    let domain: [String]
}

struct CardText: Hashable {
    let rich: String
    let plain: String
    let flavour: String?
}

struct CardSetRef: Hashable {
    let setId: String
    let label: String
}

struct CardMedia: Hashable {
    let imageUrl: String
    let artist: String
}

struct CardMetadata: Hashable {
    let cleanName: String?
    let alternateArt: Bool
    let overnumbered: Bool
    let signature: Bool
}

// MARK: - Paginated response (kept for any remaining paginated API calls)

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let page: Int
    let size: Int
    let pages: Int
}
