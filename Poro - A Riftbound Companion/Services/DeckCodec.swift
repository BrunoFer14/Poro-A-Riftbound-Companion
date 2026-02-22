import Foundation

enum DeckCodecError: LocalizedError {
    case invalidCode
    case invalidFormat
    case unsupportedVersion(Int)
    case unknownSet(Int)
    case unknownVariant(Int)
    case invalidCardCode(String)

    var errorDescription: String? {
        switch self {
        case .invalidCode: "Código de deck inválido."
        case .invalidFormat: "Formato de deck não suportado."
        case .unsupportedVersion(let v): "Versão do código não suportada: \(v)."
        case .unknownSet(let id): "Set desconhecido: \(id)."
        case .unknownVariant(let id): "Variante desconhecida: \(id)."
        case .invalidCardCode(let code): "Código de carta inválido: \(code)."
        }
    }
}

struct DeckCodeCard: Hashable {
    let cardCode: String   // e.g. "OGN-007" or "OGN-007a"
    let count: Int
}

struct DecodedDeck {
    let mainDeck: [DeckCodeCard]
    let sideboard: [DeckCodeCard]
    let chosenChampion: String?
}

enum DeckCodec {
    // MARK: - Constants

    private static let currentVersion = 3
    private static let format = 1
    private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let maxMainDeckCount = 12
    private static let maxSideboardCount = 3

    private static let setToId: [String: Int] = [
        "OGN": 0, "OGS": 1, "ARC": 2, "SFD": 3
    ]

    private static let idToSet: [Int: String] = [
        0: "OGN", 1: "OGS", 2: "ARC", 3: "SFD"
    ]

    private static let variantToId: [String: Int] = [
        "": 0, "a": 1, "s": 2, "b": 3
    ]

    private static let idToVariant: [Int: String] = [
        0: "", 1: "a", 2: "s", 3: "b"
    ]

    // MARK: - Public API

    /// Encode a Deck into a shareable deck code string.
    static func encode(deck: Deck) -> String {
        let legendCode = cardCodeFrom(card: deck.legend)
        let mainCards = deck.entries.map {
            DeckCodeCard(cardCode: cardCodeFrom(card: $0.card), count: $0.quantity)
        }
        return encode(mainDeck: mainCards, sideboard: [], chosenChampion: legendCode)
    }

    /// Encode from raw card data.
    static func encode(mainDeck: [DeckCodeCard], sideboard: [DeckCodeCard] = [], chosenChampion: String? = nil) -> String {
        var bytes: [UInt8] = []

        // Header byte: format << 4 | version
        bytes.append(UInt8((format << 4) | currentVersion))

        // Main deck: counts 12 down to 1
        encodeSection(&bytes, cards: mainDeck, maxCount: maxMainDeckCount)

        // Sideboard: counts 3 down to 1
        encodeSection(&bytes, cards: sideboard, maxCount: maxSideboardCount)

        // Chosen champion
        if let champion = chosenChampion, let parsed = parseCardCode(champion) {
            bytes.append(0x01)
            bytes.append(UInt8(parsed.setId))
            bytes.append(UInt8(parsed.variantId))
            appendVarint(&bytes, value: parsed.cardNumber)
        } else {
            bytes.append(0x00)
        }

        return base32Encode(bytes)
    }

    /// Decode a deck code string into card codes and counts.
    static func decode(_ code: String) throws -> DecodedDeck {
        let bytes = try base32Decode(code)
        guard !bytes.isEmpty else { throw DeckCodecError.invalidCode }

        var offset = 0

        // Read header
        let header = bytes[offset]; offset += 1
        let fmt = Int(header >> 4)
        let version = Int(header & 0x0F)

        guard fmt == format else { throw DeckCodecError.invalidFormat }
        guard version >= 1, version <= currentVersion else {
            throw DeckCodecError.unsupportedVersion(version)
        }

        // Main deck
        let mainDeck = try decodeSection(&offset, bytes: bytes, maxCount: maxMainDeckCount)

        // Sideboard (v2+)
        var sideboard: [DeckCodeCard] = []
        if version >= 2 {
            sideboard = try decodeSection(&offset, bytes: bytes, maxCount: maxSideboardCount)
        }

        // Chosen champion (v3+)
        var chosenChampion: String?
        if version >= 3, offset < bytes.count {
            let hasChampion = bytes[offset]; offset += 1
            if hasChampion == 0x01 {
                guard offset + 1 < bytes.count else { throw DeckCodecError.invalidCode }
                let setId = Int(bytes[offset]); offset += 1
                let variantId = Int(bytes[offset]); offset += 1
                guard let setCode = idToSet[setId] else { throw DeckCodecError.unknownSet(setId) }
                guard let variantSuffix = idToVariant[variantId] else { throw DeckCodecError.unknownVariant(variantId) }
                let cardNumber = try popVarint(&offset, bytes: bytes)
                let numStr = String(format: "%03d", cardNumber)
                chosenChampion = "\(setCode)-\(numStr)\(variantSuffix)"
            }
        }

        return DecodedDeck(mainDeck: mainDeck, sideboard: sideboard, chosenChampion: chosenChampion)
    }

    /// Build a card code string from a Card model object.
    static func cardCodeFrom(card: Card) -> String {
        let setCode = card.set.setId
        let numStr = String(format: "%03d", card.collectorNumber)
        var suffix = ""
        if card.metadata.signature {
            suffix = "s"
        } else if card.metadata.alternateArt {
            suffix = "a"
        }
        return "\(setCode)-\(numStr)\(suffix)"
    }

    // MARK: - Section encode/decode

    private struct ParsedCode {
        let setId: Int
        let variantId: Int
        let cardNumber: Int
    }

    private static func parseCardCode(_ code: String) -> ParsedCode? {
        let parts = code.split(separator: "-", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let setCode = String(parts[0])
        let rest = String(parts[1])

        guard let setId = setToId[setCode] else { return nil }

        // Split number and variant suffix
        var numStr = ""
        var variant = ""
        for ch in rest {
            if ch.isNumber {
                numStr.append(ch)
            } else {
                variant.append(ch)
            }
        }

        guard let cardNumber = Int(numStr) else { return nil }
        let variantId = variantToId[variant] ?? 0

        return ParsedCode(setId: setId, variantId: variantId, cardNumber: cardNumber)
    }

    private struct SetVariantGroup {
        let setId: Int
        let variantId: Int
        var cardNumbers: [Int]
    }

    private static func encodeSection(_ bytes: inout [UInt8], cards: [DeckCodeCard], maxCount: Int) {
        for count in stride(from: maxCount, through: 1, by: -1) {
            let cardsWithCount = cards.filter { $0.count == count }
            let groups = groupBySetAndVariant(cardsWithCount)

            appendVarint(&bytes, value: groups.count)
            for group in groups {
                appendVarint(&bytes, value: group.cardNumbers.count)
                bytes.append(UInt8(group.setId))
                bytes.append(UInt8(group.variantId))
                for num in group.cardNumbers {
                    appendVarint(&bytes, value: num)
                }
            }
        }
    }

    private static func groupBySetAndVariant(_ cards: [DeckCodeCard]) -> [SetVariantGroup] {
        var groupMap: [String: SetVariantGroup] = [:]

        for card in cards {
            guard let parsed = parseCardCode(card.cardCode) else { continue }
            let key = "\(parsed.setId)-\(parsed.variantId)"
            if groupMap[key] == nil {
                groupMap[key] = SetVariantGroup(setId: parsed.setId, variantId: parsed.variantId, cardNumbers: [])
            }
            groupMap[key]!.cardNumbers.append(parsed.cardNumber)
        }

        return groupMap.values
            .map { group in
                var g = group
                g.cardNumbers.sort()
                return g
            }
            .sorted { a, b in
                if a.setId != b.setId { return a.setId < b.setId }
                return a.variantId < b.variantId
            }
    }

    private static func decodeSection(_ offset: inout Int, bytes: [UInt8], maxCount: Int) throws -> [DeckCodeCard] {
        var cards: [DeckCodeCard] = []

        for count in stride(from: maxCount, through: 1, by: -1) {
            let numGroups = try popVarint(&offset, bytes: bytes)
            for _ in 0..<numGroups {
                let numCards = try popVarint(&offset, bytes: bytes)
                guard offset + 1 < bytes.count else { throw DeckCodecError.invalidCode }
                let setId = Int(bytes[offset]); offset += 1
                let variantId = Int(bytes[offset]); offset += 1

                guard let setCode = idToSet[setId] else { throw DeckCodecError.unknownSet(setId) }
                guard let variantSuffix = idToVariant[variantId] else { throw DeckCodecError.unknownVariant(variantId) }

                for _ in 0..<numCards {
                    let cardNumber = try popVarint(&offset, bytes: bytes)
                    let numStr = String(format: "%03d", cardNumber)
                    let code = "\(setCode)-\(numStr)\(variantSuffix)"
                    cards.append(DeckCodeCard(cardCode: code, count: count))
                }
            }
        }

        return cards
    }

    // MARK: - Varint

    private static func appendVarint(_ bytes: inout [UInt8], value: Int) {
        var v = value
        if v == 0 {
            bytes.append(0)
            return
        }
        while v != 0 {
            var byteVal = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byteVal |= 0x80 }
            bytes.append(byteVal)
        }
    }

    private static func popVarint(_ offset: inout Int, bytes: [UInt8]) throws -> Int {
        var result = 0
        var shift = 0
        while offset < bytes.count {
            let byte = bytes[offset]; offset += 1
            result |= Int(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw DeckCodecError.invalidCode
    }

    // MARK: - Base32

    private static func base32Encode(_ data: [UInt8]) -> String {
        var result = ""
        var buffer = 0
        var bitsLeft = 0

        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = (buffer >> bitsLeft) & 0x1F
                result.append(base32Alphabet[index])
            }
        }

        if bitsLeft > 0 {
            let index = (buffer << (5 - bitsLeft)) & 0x1F
            result.append(base32Alphabet[index])
        }

        return result
    }

    private static func base32Decode(_ encoded: String) throws -> [UInt8] {
        let lookup: [Character: Int] = {
            var map: [Character: Int] = [:]
            for (i, ch) in base32Alphabet.enumerated() {
                map[ch] = i
                map[Character(ch.lowercased())] = i
            }
            return map
        }()

        var buffer = 0
        var bitsLeft = 0
        var result: [UInt8] = []

        for ch in encoded {
            guard let val = lookup[ch] else { throw DeckCodecError.invalidCode }
            buffer = (buffer << 5) | val
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                result.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }

        return result
    }
}
